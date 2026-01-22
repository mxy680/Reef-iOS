//
//  EmbeddingService.swift
//  Reef
//
//  Provides sentence embeddings using Apple's NaturalLanguage framework
//  for on-device semantic search without external model dependencies.
//

import Foundation
import NaturalLanguage

/// Errors that can occur during embedding generation
enum EmbeddingError: Error, LocalizedError {
    case embeddingNotAvailable
    case emptyInput
    case embeddingFailed(String)

    var errorDescription: String? {
        switch self {
        case .embeddingNotAvailable:
            return "Sentence embedding model is not available on this device"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        case .embeddingFailed(let reason):
            return "Failed to generate embedding: \(reason)"
        }
    }
}

/// Service for generating text embeddings using Apple's NaturalLanguage framework
actor EmbeddingService {
    static let shared = EmbeddingService()

    /// Embedding dimension (Apple's sentence embedding produces 512-dimensional vectors)
    static let embeddingDimension = 512

    /// The sentence embedding model (lazy loaded)
    private var embedding: NLEmbedding?

    private init() {}

    // MARK: - Public API

    /// Check if embedding is available on this device
    func isAvailable() -> Bool {
        return NLEmbedding.sentenceEmbedding(for: .english) != nil
    }

    /// Generate an embedding for a single text
    /// - Parameter text: The text to embed
    /// - Returns: A 512-dimensional normalized vector
    func embed(_ text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        let embedding = try getEmbedding()

        guard let vector = embedding.vector(for: trimmed) else {
            throw EmbeddingError.embeddingFailed("Could not generate vector for text")
        }

        // Convert to Float array and normalize
        let floatVector = vector.map { Float($0) }
        return normalize(floatVector)
    }

    /// Generate embeddings for multiple texts (batch processing)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of 512-dimensional normalized vectors
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        let embedding = try getEmbedding()

        var results: [[Float]] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Return zero vector for empty text
                results.append(Array(repeating: 0.0, count: Self.embeddingDimension))
                continue
            }

            if let vector = embedding.vector(for: trimmed) {
                let floatVector = vector.map { Float($0) }
                results.append(normalize(floatVector))
            } else {
                // Return zero vector if embedding fails
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

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - Private Helpers

    /// Get or create the embedding model
    private func getEmbedding() throws -> NLEmbedding {
        if let existing = embedding {
            return existing
        }

        guard let newEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw EmbeddingError.embeddingNotAvailable
        }

        self.embedding = newEmbedding
        return newEmbedding
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
