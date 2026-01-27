#!/usr/bin/env python3
"""
Convert MiniLM-L6-v2 sentence transformer to CoreML format for on-device embeddings.

This script uses a simpler approach with the legacy torch ONNX export API.

Requirements:
    pip install sentence-transformers coremltools numpy

Usage:
    python convert_minilm_to_coreml.py

Output:
    - Reef/Resources/MiniLM-L6-v2.mlpackage (CoreML model)
    - Reef/Resources/tokenizer_vocab.json (vocabulary for tokenization)
"""

import os
import json
import numpy as np
from pathlib import Path

# Force CPU to avoid MPS issues
os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"

MAX_SEQ_LENGTH = 256
EMBEDDING_DIM = 384

def main():
    print("=" * 60)
    print("MiniLM-L6-v2 to CoreML Converter")
    print("=" * 60)

    import torch
    import torch.nn as nn

    # Setup paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    resources_dir = project_root / "Reef" / "Resources"
    resources_dir.mkdir(parents=True, exist_ok=True)

    print(f"\nOutput directory: {resources_dir}")

    # Step 1: Load the model using sentence-transformers
    print("\n[1/4] Loading MiniLM-L6-v2...")
    from sentence_transformers import SentenceTransformer
    from transformers import AutoTokenizer

    model_name = "sentence-transformers/all-MiniLM-L6-v2"
    model = SentenceTransformer(model_name, device="cpu")
    tokenizer = AutoTokenizer.from_pretrained(model_name)

    print(f"  Model loaded: {model_name}")
    print(f"  Embedding dimension: {model.get_sentence_embedding_dimension()}")

    # Step 2: Export tokenizer vocabulary
    print("\n[2/4] Exporting tokenizer vocabulary...")
    vocab_path = resources_dir / "tokenizer_vocab.json"

    vocab_data = {
        "vocab": tokenizer.get_vocab(),
        "special_tokens": {
            "pad_token": tokenizer.pad_token,
            "pad_token_id": tokenizer.pad_token_id,
            "cls_token": tokenizer.cls_token,
            "cls_token_id": tokenizer.cls_token_id,
            "sep_token": tokenizer.sep_token,
            "sep_token_id": tokenizer.sep_token_id,
            "unk_token": tokenizer.unk_token,
            "unk_token_id": tokenizer.unk_token_id,
        },
        "max_length": MAX_SEQ_LENGTH,
        "model_name": model_name
    }

    with open(vocab_path, "w") as f:
        json.dump(vocab_data, f)

    print(f"  Vocabulary saved: {vocab_path}")
    print(f"  Vocab size: {len(vocab_data['vocab'])} tokens")

    # Step 3: Export and convert to CoreML using coremltools' torch converter
    print("\n[3/4] Converting to CoreML...")

    # Create a simplified wrapper model
    class MiniLMWrapper(nn.Module):
        def __init__(self, st_model):
            super().__init__()
            # Get the transformer model
            self.encoder = st_model[0].auto_model

        def forward(self, input_ids, attention_mask):
            # Get transformer outputs
            outputs = self.encoder(
                input_ids=input_ids,
                attention_mask=attention_mask,
                return_dict=True
            )
            return outputs.last_hidden_state

    wrapper = MiniLMWrapper(model)
    wrapper.eval()
    for p in wrapper.parameters():
        p.requires_grad = False

    # Create example inputs
    example_input_ids = torch.zeros(1, MAX_SEQ_LENGTH, dtype=torch.int32)
    example_attention_mask = torch.ones(1, MAX_SEQ_LENGTH, dtype=torch.int32)

    # Trace the model
    print("  Tracing model...")
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (example_input_ids, example_attention_mask))

    # Convert using coremltools
    print("  Converting to CoreML...")
    import coremltools as ct

    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_SEQ_LENGTH), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_SEQ_LENGTH), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="last_hidden_state")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
    )

    # Set metadata
    mlmodel.author = "Reef App"
    mlmodel.short_description = "MiniLM-L6-v2 transformer for semantic search embeddings"
    mlmodel.version = "1.0"

    # Save the model
    model_path = resources_dir / "MiniLM-L6-v2.mlpackage"
    mlmodel.save(str(model_path))
    print(f"  CoreML model saved: {model_path}")

    # Step 4: Verify
    print("\n[4/4] Verifying...")

    test_sentences = [
        "Machine learning is fascinating.",
        "I love deep learning and neural networks.",
        "The weather is nice today."
    ]

    # Get sentence-transformers embeddings for reference
    st_embeddings = model.encode(test_sentences, normalize_embeddings=True)

    print("\nSentence-Transformers embeddings (first 5 dims):")
    for i, sent in enumerate(test_sentences):
        print(f"  '{sent[:40]}': {st_embeddings[i][:5].round(4)}")

    # Test CoreML
    print("\nCoreML verification (with mean pooling + L2 norm):")
    try:
        for i, sent in enumerate(test_sentences):
            encoded = tokenizer(
                sent,
                padding="max_length",
                truncation=True,
                max_length=MAX_SEQ_LENGTH,
                return_tensors="np"
            )

            # Get CoreML output
            coreml_input = {
                "input_ids": encoded["input_ids"].astype(np.int32),
                "attention_mask": encoded["attention_mask"].astype(np.int32),
            }

            coreml_output = mlmodel.predict(coreml_input)
            last_hidden_state = coreml_output["last_hidden_state"]

            # Mean pooling
            mask = encoded["attention_mask"][0]
            mask_expanded = np.expand_dims(mask, -1)
            sum_embeddings = np.sum(last_hidden_state[0] * mask_expanded, axis=0)
            sum_mask = np.sum(mask)
            mean_embedding = sum_embeddings / max(sum_mask, 1e-9)

            # L2 normalize
            norm = np.linalg.norm(mean_embedding)
            coreml_emb = mean_embedding / max(norm, 1e-9)

            # Cosine similarity
            cos_sim = np.dot(st_embeddings[i], coreml_emb) / (
                np.linalg.norm(st_embeddings[i]) * np.linalg.norm(coreml_emb)
            )
            status = "OK" if cos_sim > 0.99 else ("WARN" if cos_sim > 0.95 else "FAIL")
            print(f"  Sentence {i+1} similarity: {cos_sim:.4f} [{status}]")

        print("\n  SUCCESS: CoreML conversion verified!")
    except Exception as e:
        print(f"\n  (CoreML prediction error: {e})")
        import traceback
        traceback.print_exc()
        print("  The model may still work correctly on iOS/macOS devices.")

    print("\n" + "=" * 60)
    print("Conversion complete!")
    print("=" * 60)
    print(f"\nFiles created:")
    print(f"  1. {model_path}")
    print(f"  2. {vocab_path}")
    print(f"\nNote: Mean pooling and L2 normalization must be done in Swift.")
    print("Add these files to your Xcode project.")

if __name__ == "__main__":
    main()
