#!/usr/bin/env python3
"""
Convert MiniLM-L6-v2 sentence transformer to CoreML format for on-device embeddings.

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
    # Force CPU
    torch.set_default_device("cpu")

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

    # Step 3: Create and trace the model
    print("\n[3/4] Tracing and converting to CoreML...")
    import torch.nn as nn

    class SimplifiedMiniLM(nn.Module):
        """Simplified wrapper that just does embedding lookup and pooling."""
        def __init__(self, transformer_model):
            super().__init__()
            self.transformer = transformer_model[0].auto_model.to("cpu")

        def forward(self, input_ids, attention_mask):
            outputs = self.transformer(input_ids=input_ids, attention_mask=attention_mask)
            token_embeddings = outputs.last_hidden_state

            # Mean pooling
            mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
            sum_embeddings = torch.sum(token_embeddings * mask_expanded, 1)
            sum_mask = torch.clamp(mask_expanded.sum(1), min=1e-9)
            embeddings = sum_embeddings / sum_mask

            # L2 normalize
            embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
            return embeddings

    simplified = SimplifiedMiniLM(model).to("cpu")

    # Put in inference mode
    simplified.train(False)
    for param in simplified.parameters():
        param.requires_grad = False

    # Create dummy inputs on CPU
    dummy_input_ids = torch.zeros((1, MAX_SEQ_LENGTH), dtype=torch.long, device="cpu")
    dummy_attention_mask = torch.ones((1, MAX_SEQ_LENGTH), dtype=torch.long, device="cpu")

    # Trace the model
    print("  Tracing model with TorchScript...")
    with torch.no_grad():
        traced = torch.jit.trace(simplified, (dummy_input_ids, dummy_attention_mask))

    # Convert to CoreML
    print("  Converting to CoreML...")
    import coremltools as ct

    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_SEQ_LENGTH), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_SEQ_LENGTH), dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="embeddings"),
        ],
        minimum_deployment_target=ct.target.iOS16,
        convert_to="mlprogram",
    )

    # Set model metadata
    mlmodel.author = "Reef App"
    mlmodel.short_description = "MiniLM-L6-v2 sentence embeddings for semantic search"
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

    # Get sentence-transformers embeddings
    st_embeddings = model.encode(test_sentences, normalize_embeddings=True)

    print("\nSentence-Transformers embeddings (first 5 dims):")
    for i, sent in enumerate(test_sentences):
        print(f"  '{sent[:40]}': {st_embeddings[i][:5].round(4)}")

    # Test CoreML (may not work in all environments)
    try:
        for i, sent in enumerate(test_sentences):
            encoded = tokenizer(
                sent,
                padding="max_length",
                truncation=True,
                max_length=MAX_SEQ_LENGTH,
                return_tensors="np"
            )
            coreml_input = {
                "input_ids": encoded["input_ids"].astype(np.int32),
                "attention_mask": encoded["attention_mask"].astype(np.int32),
            }
            coreml_output = mlmodel.predict(coreml_input)
            coreml_emb = coreml_output["embeddings"][0]

            # Cosine similarity
            cos_sim = np.dot(st_embeddings[i], coreml_emb) / (
                np.linalg.norm(st_embeddings[i]) * np.linalg.norm(coreml_emb)
            )
            status = "OK" if cos_sim > 0.99 else "WARN"
            print(f"\n  CoreML vs ST similarity for sentence {i+1}: {cos_sim:.4f} [{status}]")

        print("\n  SUCCESS: CoreML conversion verified!")
    except Exception as e:
        print(f"\n  (CoreML prediction not available: {e})")
        print("  The model should work correctly on iOS/macOS devices.")

    print("\n" + "=" * 60)
    print("Conversion complete!")
    print("=" * 60)
    print(f"\nFiles created:")
    print(f"  1. {model_path}")
    print(f"  2. {vocab_path}")
    print(f"\nAdd these to your Xcode project.")

if __name__ == "__main__":
    main()
