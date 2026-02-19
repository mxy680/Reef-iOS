//
//  EmbeddingServiceTests.swift
//  ReefTests
//
//  Integration tests for EmbeddingService hitting the real local dev server.
//  Requires Reef-Server running at http://localhost:8000.
//

import Testing
import Foundation
@testable import Reef

@Suite("EmbeddingService Integration", .serialized)
struct EmbeddingServiceIntegrationTests {

    private func makeService() -> EmbeddingService {
        let aiService = AIService(baseURL: "http://localhost:8000")
        return EmbeddingService(aiService: aiService)
    }

    // MARK: - Single Embed

    @Test("embed success returns 384-dim vector")
    func embedSuccessReturns384DimVector() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let result = try await service.embed("hello world")

        #expect(result.count == 384)
    }

    @Test("embed empty text throws emptyInput")
    func embedEmptyTextThrowsEmptyInput() async throws {
        let service = makeService()

        await #expect(throws: EmbeddingError.self) {
            _ = try await service.embed("")
        }
    }

    @Test("embed whitespace-only throws emptyInput")
    func embedWhitespaceOnlyThrowsEmptyInput() async throws {
        let service = makeService()

        await #expect(throws: EmbeddingError.self) {
            _ = try await service.embed("   \n\t  ")
        }
    }

    @Test("embed trims whitespace before sending")
    func embedTrimsWhitespaceBeforeSending() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let result = try await service.embed("  hello  ")

        #expect(result.count == 384)
    }

    // MARK: - Batch Embed

    @Test("embedBatch success returns vectors")
    func embedBatchSuccessReturnsVectors() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let result = try await service.embedBatch(["a", "b", "c"])

        #expect(result.count == 3)
        for vector in result {
            #expect(vector.count == 384)
        }
    }

    @Test("embedBatch filters empty strings with zero vectors")
    func embedBatchFiltersEmptyStringsWithZeroVectors() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let result = try await service.embedBatch(["hello", "", "world"])

        #expect(result.count == 3)
        #expect(result[1] == Array(repeating: Float(0.0), count: EmbeddingService.embeddingDimension))
    }

    @Test("embedBatch all empty returns zero vectors")
    func embedBatchAllEmptyReturnsZeroVectors() async throws {
        let service = makeService()

        let result = try await service.embedBatch(["", "  ", "\n"])

        #expect(result.count == 3)
        for vector in result {
            #expect(vector == Array(repeating: Float(0.0), count: EmbeddingService.embeddingDimension))
        }
    }

    // MARK: - Cosine Similarity (Real Embeddings)

    @Test("cosine similarity of identical real embeddings ≈ 1.0")
    func cosineSimilarityOfIdenticalRealEmbeddingsApproximatesOne() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let text = "the mitochondria is the powerhouse of the cell"
        let first = try await service.embed(text)
        let second = try await service.embed(text)

        let similarity = service.cosineSimilarity(first, second)
        #expect(similarity > 0.99)
    }

    @Test("cosine similarity of related texts > unrelated")
    func cosineSimilarityOfRelatedTextsGreaterThanUnrelated() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = makeService()

        let calculus = try await service.embed("calculus derivatives")
        let integration = try await service.embed("integration formulas")
        let cooking = try await service.embed("cooking recipes")

        let relatedSimilarity = service.cosineSimilarity(calculus, integration)
        let unrelatedSimilarity = service.cosineSimilarity(calculus, cooking)

        #expect(relatedSimilarity > unrelatedSimilarity)
    }

    // MARK: - Cosine Similarity (Known Vectors)

    @Test("cosine similarity math functions work")
    func cosineSimilarityMathFunctionsWork() async throws {
        let service = makeService()

        let identical = service.cosineSimilarity([1.0, 0.0, 0.0], [1.0, 0.0, 0.0])
        #expect(abs(identical - 1.0) < 0.001)

        let orthogonal = service.cosineSimilarity([1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
        #expect(abs(orthogonal) < 0.001)
    }

    // MARK: - Static Properties

    @Test("embedding dimension is 384")
    func embeddingDimensionIs384() {
        #expect(EmbeddingService.embeddingDimension == 384)
    }

    @Test("embedding version is 2")
    func embeddingVersionIs2() {
        #expect(EmbeddingService.embeddingVersion == 2)
    }
}
