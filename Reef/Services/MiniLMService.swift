//
//  MiniLMService.swift
//  Reef
//
//  CoreML inference service for MiniLM-L6-v2 sentence embeddings.
//  Handles model loading, inference, and mean pooling with L2 normalization.
//

import Foundation
import CoreML
import Accelerate

/// Service for generating sentence embeddings using MiniLM-L6-v2
actor MiniLMService {
    // MARK: - Constants

    /// Embedding dimension for MiniLM-L6-v2
    static let embeddingDimension = 384

    /// Maximum sequence length
    static let maxSequenceLength = 256

    // MARK: - Properties

    /// The CoreML model
    private var model: MLModel?

    /// Whether the service is initialized
    private var isInitialized = false

    // MARK: - Initialization

    /// Load the CoreML model
    func loadModel() throws {
        guard !isInitialized else { return }

        guard let modelURL = Bundle.main.url(forResource: "MiniLM-L6-v2", withExtension: "mlmodelc") else {
            throw MiniLMError.modelNotFound
        }

        // Configure for optimal performance
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // Use Neural Engine when available

        model = try MLModel(contentsOf: modelURL, configuration: config)
        isInitialized = true

        print("[MiniLMService] Model loaded successfully")
    }

    // MARK: - Inference

    /// Generate embedding from tokenized input
    /// - Parameters:
    ///   - inputIds: Token IDs from tokenizer
    ///   - attentionMask: Attention mask (1 for real tokens, 0 for padding)
    /// - Returns: L2-normalized 384-dimensional embedding
    func embed(inputIds: [Int32], attentionMask: [Int32]) throws -> [Float] {
        guard isInitialized, let model = model else {
            throw MiniLMError.notInitialized
        }

        guard inputIds.count == Self.maxSequenceLength,
              attentionMask.count == Self.maxSequenceLength else {
            throw MiniLMError.invalidInputShape
        }

        // Create MLMultiArrays for input
        let inputIdsArray = try createMLMultiArray(from: inputIds, shape: [1, Self.maxSequenceLength])
        let attentionMaskArray = try createMLMultiArray(from: attentionMask, shape: [1, Self.maxSequenceLength])

        // Create feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])

        // Run inference
        let output = try model.prediction(from: inputFeatures)

        // Get the last_hidden_state output (shape: [1, seq_len, 384])
        guard let lastHiddenState = output.featureValue(for: "last_hidden_state")?.multiArrayValue else {
            throw MiniLMError.invalidOutput
        }

        // Debug: print shape to verify tensor layout
        let shape = lastHiddenState.shape.map { $0.intValue }
        print("[MiniLMService] Output shape: \(shape)")

        // Apply mean pooling with attention mask
        let embedding = meanPool(lastHiddenState: lastHiddenState, attentionMask: attentionMask, shape: shape)

        // L2 normalize
        return l2Normalize(embedding)
    }

    // MARK: - Private Methods

    /// Create MLMultiArray from Int32 array
    private func createMLMultiArray(from array: [Int32], shape: [Int]) throws -> MLMultiArray {
        let mlArray = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: .int32)

        for (index, value) in array.enumerated() {
            mlArray[index] = NSNumber(value: value)
        }

        return mlArray
    }

    /// Apply mean pooling to token embeddings using attention mask
    private func meanPool(lastHiddenState: MLMultiArray, attentionMask: [Int32], shape: [Int]) -> [Float] {
        let embDim = Self.embeddingDimension

        // Determine tensor layout from shape
        // Expected: [1, seq_len, 384] or [1, 384, seq_len]
        let seqLen: Int
        let seqFirst: Bool  // Is sequence dimension before embedding dimension?

        if shape.count == 3 {
            if shape[2] == embDim {
                // Shape is [batch, seq_len, emb_dim]
                seqLen = shape[1]
                seqFirst = true
            } else if shape[1] == embDim {
                // Shape is [batch, emb_dim, seq_len]
                seqLen = shape[2]
                seqFirst = false
            } else {
                print("[MiniLMService] Warning: Unexpected shape \(shape), using default layout")
                seqLen = Self.maxSequenceLength
                seqFirst = true
            }
        } else {
            print("[MiniLMService] Warning: Expected 3D tensor, got \(shape.count)D")
            seqLen = Self.maxSequenceLength
            seqFirst = true
        }

        var sumEmbedding = [Float](repeating: 0, count: embDim)
        var tokenCount: Float = 0

        // Iterate over sequence positions
        let actualSeqLen = min(seqLen, attentionMask.count)
        for seqIdx in 0..<actualSeqLen {
            // Skip padding tokens
            guard attentionMask[seqIdx] == 1 else { continue }

            tokenCount += 1

            // Add this token's embedding to the sum
            for embIdx in 0..<embDim {
                let index: Int
                if seqFirst {
                    // [batch, seq, emb] - row-major: index = seq * emb_dim + emb
                    index = seqIdx * embDim + embIdx
                } else {
                    // [batch, emb, seq] - row-major: index = emb * seq_len + seq
                    index = embIdx * seqLen + seqIdx
                }
                let value = lastHiddenState[index].floatValue
                sumEmbedding[embIdx] += value
            }
        }

        // Avoid division by zero
        guard tokenCount > 0 else {
            return sumEmbedding
        }

        // Compute mean
        return sumEmbedding.map { $0 / tokenCount }
    }

    /// L2 normalize a vector using Accelerate
    private func l2Normalize(_ vector: [Float]) -> [Float] {
        var sumSquares: Float = 0
        vDSP_svesq(vector, 1, &sumSquares, vDSP_Length(vector.count))

        let magnitude = sqrt(sumSquares)
        guard magnitude > 0 else { return vector }

        var result = [Float](repeating: 0, count: vector.count)
        var divisor = magnitude
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))

        return result
    }
}

// MARK: - Errors

enum MiniLMError: Error, LocalizedError {
    case modelNotFound
    case notInitialized
    case invalidInputShape
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "MiniLM-L6-v2 model not found in bundle"
        case .notInitialized:
            return "MiniLM service not initialized - call loadModel() first"
        case .invalidInputShape:
            return "Invalid input shape - expected \(MiniLMService.maxSequenceLength) tokens"
        case .invalidOutput:
            return "Invalid model output format"
        }
    }
}
