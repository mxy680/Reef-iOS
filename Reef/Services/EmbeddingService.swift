//
//  EmbeddingService.swift
//  Reef
//
//  Facade for text embeddings. Tries MiniLM-L6-v2 (384-dim) first for better
//  quality, falls back to Apple's NLEmbedding (512-dim) if MiniLM unavailable.
//

import Foundation
import NaturalLanguage

/// The embedding provider being used
enum EmbeddingProvider: String {
    case miniLM = "MiniLM-L6-v2"
    case nlEmbedding = "NLEmbedding"
}

/// Errors that can occur during embedding generation
enum EmbeddingError: Error, LocalizedError {
    case embeddingNotAvailable
    case emptyInput
    case embeddingFailed(String)
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .embeddingNotAvailable:
            return "No embedding model is available on this device"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        case .embeddingFailed(let reason):
            return "Failed to generate embedding: \(reason)"
        case .notInitialized:
            return "Embedding service not initialized"
        }
    }
}

/// Facade service for generating text embeddings
/// Routes to MiniLM-L6-v2 (preferred) or NLEmbedding (fallback)
actor EmbeddingService {
    static let shared = EmbeddingService()

    /// Current embedding dimension (depends on active provider)
    private(set) var embeddingDimension: Int = 384

    /// Active embedding provider
    private(set) var activeProvider: EmbeddingProvider?

    /// Apple's NLEmbedding (fallback)
    private var nlEmbedding: NLEmbedding?

    /// Whether the service has been initialized
    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize the embedding service
    /// Tries MiniLM first, falls back to NLEmbedding
    func initialize() async {
        guard !isInitialized else { return }

        // Try MiniLM first
        do {
            try await MiniLMEmbeddingService.shared.initialize()
            if await MiniLMEmbeddingService.shared.isAvailable() {
                activeProvider = .miniLM
                embeddingDimension = MiniLMEmbeddingService.embeddingDimension
                isInitialized = true
                print("[Embedding] Using MiniLM-L6-v2 (384 dimensions)")
                return
            }
        } catch {
            print("[Embedding] MiniLM initialization failed: \(error). Trying fallback...")
        }

        // Fall back to NLEmbedding
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            nlEmbedding = embedding
            activeProvider = .nlEmbedding
            embeddingDimension = 512
            isInitialized = true
            print("[Embedding] Using NLEmbedding fallback (512 dimensions)")
        } else {
            print("[Embedding] WARNING: No embedding provider available!")
        }
    }

    // MARK: - Public API

    /// Check if embedding is available on this device
    func isAvailable() -> Bool {
        return activeProvider != nil
    }

    /// Get the current embedding dimension
    func currentDimension() -> Int {
        return embeddingDimension
    }

    /// Generate an embedding for a single text
    /// - Parameter text: The text to embed
    /// - Returns: A normalized embedding vector
    func embed(_ text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        guard let provider = activeProvider else {
            throw EmbeddingError.notInitialized
        }

        switch provider {
        case .miniLM:
            return try await MiniLMEmbeddingService.shared.embed(trimmed)

        case .nlEmbedding:
            return try embedWithNL(trimmed)
        }
    }

    /// Generate embeddings for multiple texts (batch processing)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of normalized embedding vectors
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        guard let provider = activeProvider else {
            throw EmbeddingError.notInitialized
        }

        switch provider {
        case .miniLM:
            return try await MiniLMEmbeddingService.shared.embedBatch(texts)

        case .nlEmbedding:
            return try embedBatchWithNL(texts)
        }
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

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - NLEmbedding Fallback

    /// Embed using NLEmbedding
    private func embedWithNL(_ text: String) throws -> [Float] {
        guard let embedding = nlEmbedding else {
            throw EmbeddingError.embeddingNotAvailable
        }

        guard let vector = embedding.vector(for: text) else {
            throw EmbeddingError.embeddingFailed("Could not generate vector for text")
        }

        let floatVector = vector.map { Float($0) }
        return normalize(floatVector)
    }

    /// Batch embed using NLEmbedding
    private func embedBatchWithNL(_ texts: [String]) throws -> [[Float]] {
        guard let embedding = nlEmbedding else {
            throw EmbeddingError.embeddingNotAvailable
        }

        var results: [[Float]] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                results.append(Array(repeating: 0.0, count: embeddingDimension))
                continue
            }

            if let vector = embedding.vector(for: trimmed) {
                let floatVector = vector.map { Float($0) }
                results.append(normalize(floatVector))
            } else {
                results.append(Array(repeating: 0.0, count: embeddingDimension))
            }
        }

        return results
    }

    /// L2 normalize a vector
    private func normalize(_ vector: [Float]) -> [Float] {
        var sumSquares: Float = 0
        for v in vector {
            sumSquares += v * v
        }

        let magnitude = sqrt(sumSquares)
        guard magnitude > 0 else { return vector }

        return vector.map { $0 / magnitude }
    }
}
