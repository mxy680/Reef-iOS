//
//  MiniLMEmbeddingService.swift
//  Reef
//
//  CoreML inference wrapper for MiniLM-L6-v2 sentence embeddings.
//  Provides 384-dimensional embeddings for semantic search.
//

import Foundation
import CoreML
import Accelerate

/// Errors that can occur during MiniLM embedding generation
enum MiniLMError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed(String)
    case tokenizerNotInitialized
    case inferenceFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "MiniLM CoreML model not found in bundle"
        case .modelLoadFailed(let message):
            return "Failed to load MiniLM model: \(message)"
        case .tokenizerNotInitialized:
            return "Tokenizer not initialized"
        case .inferenceFailed(let message):
            return "MiniLM inference failed: \(message)"
        case .invalidOutput:
            return "Invalid model output format"
        }
    }
}

/// Service for generating embeddings using MiniLM-L6-v2 CoreML model
actor MiniLMEmbeddingService {
    /// Singleton instance
    static let shared = MiniLMEmbeddingService()

    /// Embedding dimension (MiniLM-L6-v2 produces 384-dimensional vectors)
    static let embeddingDimension = 384

    /// Maximum sequence length (must match CoreML model)
    private let maxSequenceLength = 128

    /// The CoreML model
    private var model: MLModel?

    /// Whether the service has been initialized
    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize the service by loading the CoreML model
    func initialize() async throws {
        guard !isInitialized else { return }

        // Initialize tokenizer first
        try WordPieceTokenizer.shared.initialize()

        // Load the CoreML model (Xcode compiles .mlpackage to .mlmodelc)
        let modelURL: URL
        if let compiledURL = Bundle.main.url(forResource: "MiniLM-L6-v2", withExtension: "mlmodelc") {
            print("[MiniLM] Found compiled model at: \(compiledURL)")
            modelURL = compiledURL
        } else if let packageURL = Bundle.main.url(forResource: "MiniLM-L6-v2", withExtension: "mlpackage") {
            print("[MiniLM] Found model package at: \(packageURL)")
            modelURL = packageURL
        } else {
            // Debug: List what's actually in the bundle
            if let resourcePath = Bundle.main.resourcePath {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("[MiniLM] Bundle resources: \(contents?.prefix(20) ?? [])")
            }
            throw MiniLMError.modelNotFound
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // Use Neural Engine when available

        do {
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
            self.isInitialized = true
            print("[MiniLM] Model loaded successfully from: \(modelURL.lastPathComponent)")
        } catch {
            print("[MiniLM] Model load error: \(error)")
            throw MiniLMError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Check if service is available
    func isAvailable() -> Bool {
        return isInitialized && model != nil
    }

    // MARK: - Public API

    /// Generate an embedding for a single text
    /// - Parameter text: The text to embed
    /// - Returns: A 384-dimensional normalized vector
    func embed(_ text: String) async throws -> [Float] {
        guard isInitialized, let model = model else {
            throw MiniLMError.modelLoadFailed("Service not initialized")
        }

        guard WordPieceTokenizer.shared.isReady else {
            throw MiniLMError.tokenizerNotInitialized
        }

        // Tokenize
        let tokenized = WordPieceTokenizer.shared.tokenize(text)

        // Prepare model inputs
        let inputFeatures = try createInputFeatures(
            inputIds: tokenized.inputIds,
            attentionMask: tokenized.attentionMask
        )

        // Run inference
        let output = try await model.prediction(from: inputFeatures)

        // Extract and pool embeddings
        let embedding = try extractEmbedding(from: output, attentionMask: tokenized.attentionMask)

        return embedding
    }

    /// Generate embeddings for multiple texts (batch processing)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of 384-dimensional normalized vectors
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        // Process sequentially (CoreML batch support varies by model)
        var results: [[Float]] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Return zero vector for empty text
                results.append(Array(repeating: 0.0, count: Self.embeddingDimension))
            } else {
                do {
                    let embedding = try await embed(trimmed)
                    results.append(embedding)
                } catch {
                    // Return zero vector on error
                    print("[MiniLM] Error embedding text: \(error)")
                    results.append(Array(repeating: 0.0, count: Self.embeddingDimension))
                }
            }
        }

        return results
    }

    // MARK: - Private Helpers

    /// Create MLFeatureProvider for model input
    private func createInputFeatures(inputIds: [Int32], attentionMask: [Int32]) throws -> MLFeatureProvider {
        // Create MLMultiArray for input_ids
        let inputIdsArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)
        for i in 0..<min(inputIds.count, maxSequenceLength) {
            inputIdsArray[i] = NSNumber(value: inputIds[i])
        }

        // Create MLMultiArray for attention_mask
        let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)
        for i in 0..<min(attentionMask.count, maxSequenceLength) {
            attentionMaskArray[i] = NSNumber(value: attentionMask[i])
        }

        // Create feature provider
        let features: [String: MLFeatureValue] = [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ]

        return try MLDictionaryFeatureProvider(dictionary: features)
    }

    /// Extract embedding from model output using mean pooling
    private func extractEmbedding(from output: MLFeatureProvider, attentionMask: [Int32]) throws -> [Float] {
        // The model outputs "last_hidden_state" with shape [1, seq_len, 384]
        guard let hiddenStateValue = output.featureValue(for: "last_hidden_state"),
              let hiddenStateArray = hiddenStateValue.multiArrayValue else {
            throw MiniLMError.invalidOutput
        }

        let shape = hiddenStateArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[2] == Self.embeddingDimension else {
            throw MiniLMError.invalidOutput
        }

        let seqLen = shape[1]
        let hiddenSize = shape[2]

        // Mean pooling: average over sequence positions weighted by attention mask
        var sumEmbedding = Array(repeating: Float(0), count: hiddenSize)
        var sumMask: Float = 0

        // Access the underlying buffer
        let pointer = hiddenStateArray.dataPointer.bindMemory(to: Float.self, capacity: seqLen * hiddenSize)

        for i in 0..<seqLen {
            let mask = Float(attentionMask[i])
            sumMask += mask

            if mask > 0 {
                for j in 0..<hiddenSize {
                    sumEmbedding[j] += pointer[i * hiddenSize + j] * mask
                }
            }
        }

        // Avoid division by zero
        sumMask = max(sumMask, 1e-9)

        // Compute mean
        var embedding = sumEmbedding.map { $0 / sumMask }

        // L2 normalize
        embedding = normalize(embedding)

        return embedding
    }

    /// L2 normalize a vector using Accelerate
    private func normalize(_ vector: [Float]) -> [Float] {
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
