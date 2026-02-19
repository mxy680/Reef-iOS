//
//  EmbeddingService.swift
//  Reef
//
//  Provides sentence embeddings via server-side MiniLM-L6-v2
//  for high-quality semantic search.
//

import Foundation
import Accelerate

/// Errors that can occur during embedding generation
enum EmbeddingError: Error, LocalizedError {
    case embeddingNotAvailable
    case emptyInput
    case embeddingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .embeddingNotAvailable:
            return "Embedding service is not available"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        case .embeddingFailed(let reason):
            return "Failed to generate embedding: \(reason)"
        case .networkError(let error):
            return "Network error during embedding: \(error.localizedDescription)"
        }
    }
}

/// Service for generating text embeddings using server-side MiniLM-L6-v2
actor EmbeddingService {
    static let shared = EmbeddingService()

    /// Embedding dimension (MiniLM-L6-v2 produces 384-dimensional vectors)
    static let embeddingDimension = 384

    /// Embedding model version - increment when changing models to trigger re-indexing
    static let embeddingVersion = 2  // v1 = NLEmbedding (512d), v2 = MiniLM (384d)

    private let aiService: AIService

    init(aiService: AIService = AIService.shared) {
        self.aiService = aiService
    }

    // MARK: - Public API

    /// Check if embedding is available (always true since we use server)
    nonisolated func isAvailable() -> Bool {
        return true
    }

    /// Generate an embedding for a single text
    /// - Parameter text: The text to embed
    /// - Returns: A 384-dimensional normalized vector
    func embed(_ text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        do {
            let embeddings = try await aiService.embed(texts: [trimmed])
            guard let embedding = embeddings.first else {
                throw EmbeddingError.embeddingFailed("No embedding returned from server")
            }
            return embedding
        } catch let error as AIServiceError {
            throw EmbeddingError.networkError(error)
        } catch {
            throw EmbeddingError.embeddingFailed(error.localizedDescription)
        }
    }

    /// Generate embeddings for multiple texts (batch processing)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of 384-dimensional normalized vectors
    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        // Filter and track indices of non-empty texts
        var nonEmptyTexts: [String] = []
        var indexMap: [Int] = []  // Maps result index to original index

        for (index, text) in texts.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                nonEmptyTexts.append(trimmed)
                indexMap.append(index)
            }
        }

        // If all texts are empty, return zero vectors
        if nonEmptyTexts.isEmpty {
            return texts.map { _ in Array(repeating: 0.0, count: Self.embeddingDimension) }
        }

        // Get embeddings from server
        let serverEmbeddings: [[Float]]
        do {
            serverEmbeddings = try await aiService.embed(texts: nonEmptyTexts)
        } catch let error as AIServiceError {
            // On network error, return zero vectors
            print("[EmbeddingService] Network error, returning zero vectors: \(error)")
            return texts.map { _ in Array(repeating: 0.0, count: Self.embeddingDimension) }
        } catch {
            print("[EmbeddingService] Failed to embed batch: \(error)")
            return texts.map { _ in Array(repeating: 0.0, count: Self.embeddingDimension) }
        }

        // Build result array with zero vectors for empty texts
        var results: [[Float]] = texts.map { _ in Array(repeating: 0.0, count: Self.embeddingDimension) }
        for (serverIndex, originalIndex) in indexMap.enumerated() {
            if serverIndex < serverEmbeddings.count {
                results[originalIndex] = serverEmbeddings[serverIndex]
            }
        }

        return results
    }

    /// Calculate cosine similarity between two vectors
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Cosine similarity score between -1 and 1
    nonisolated func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
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
