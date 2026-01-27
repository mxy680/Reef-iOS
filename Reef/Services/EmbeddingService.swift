//
//  EmbeddingService.swift
//  Reef
//
//  Provides sentence embeddings using MiniLM-L6-v2 via CoreML
//  for high-quality on-device semantic search.
//

import Foundation
import Accelerate

/// Errors that can occur during embedding generation
enum EmbeddingError: Error, LocalizedError {
    case embeddingNotAvailable
    case emptyInput
    case embeddingFailed(String)
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .embeddingNotAvailable:
            return "Sentence embedding model is not available on this device"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        case .embeddingFailed(let reason):
            return "Failed to generate embedding: \(reason)"
        case .notInitialized:
            return "Embedding service not initialized - call initialize() first"
        }
    }
}

/// Service for generating text embeddings using MiniLM-L6-v2
actor EmbeddingService {
    static let shared = EmbeddingService()

    /// Embedding dimension (MiniLM-L6-v2 produces 384-dimensional vectors)
    static let embeddingDimension = 384

    /// Embedding model version - increment when changing models to trigger re-indexing
    static let embeddingVersion = 2  // v1 = NLEmbedding (512d), v2 = MiniLM (384d)

    /// The tokenizer
    private let tokenizer = WordPieceTokenizer()

    /// The MiniLM inference service
    private let miniLM = MiniLMService()

    /// Whether the service has been initialized
    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize the embedding service (load tokenizer vocab and CoreML model)
    func initialize() async throws {
        guard !isInitialized else { return }

        do {
            // Load tokenizer vocabulary
            try await tokenizer.loadVocabulary()

            // Load CoreML model
            try await miniLM.loadModel()

            isInitialized = true
            print("[EmbeddingService] Initialized with MiniLM-L6-v2 (v\(Self.embeddingVersion))")
        } catch {
            print("[EmbeddingService] Initialization failed: \(error)")
            throw error
        }
    }

    // MARK: - Public API

    /// Check if embedding is available (service is initialized)
    func isAvailable() -> Bool {
        return isInitialized
    }

    /// Generate an embedding for a single text
    /// - Parameter text: The text to embed
    /// - Returns: A 384-dimensional normalized vector
    func embed(_ text: String) async throws -> [Float] {
        guard isInitialized else {
            throw EmbeddingError.notInitialized
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        do {
            // Tokenize
            let tokenized = try await tokenizer.tokenize(trimmed)

            // Generate embedding
            let embedding = try await miniLM.embed(
                inputIds: tokenized.inputIds,
                attentionMask: tokenized.attentionMask
            )

            return embedding
        } catch {
            throw EmbeddingError.embeddingFailed(error.localizedDescription)
        }
    }

    /// Generate embeddings for multiple texts (batch processing)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of 384-dimensional normalized vectors
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        guard isInitialized else {
            throw EmbeddingError.notInitialized
        }

        var results: [[Float]] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Return zero vector for empty text
                results.append(Array(repeating: 0.0, count: Self.embeddingDimension))
                continue
            }

            do {
                let tokenized = try await tokenizer.tokenize(trimmed)
                let embedding = try await miniLM.embed(
                    inputIds: tokenized.inputIds,
                    attentionMask: tokenized.attentionMask
                )
                results.append(embedding)
            } catch {
                // Return zero vector if embedding fails
                print("[EmbeddingService] Failed to embed text: \(error)")
                results.append(Array(repeating: 0.0, count: Self.embeddingDimension))
            }
        }

        return results
    }

    /// Calculate cosine similarity between two vectors
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Cosine similarity score between -1 and 1
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use Accelerate for SIMD-optimized computation
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
