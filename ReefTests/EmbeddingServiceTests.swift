//
//  EmbeddingServiceTests.swift
//  ReefTests
//
//  Tests for EmbeddingService with mocked AIService dependency.
//

import Testing
@testable import Reef
import Foundation

@Suite("EmbeddingService")
struct EmbeddingServiceTests {

    // MARK: - Single Embed

    @Test("embed success returns embedding vector")
    func embed_success_returnsEmbedding() async throws {
        let mockAI = MockAIService()
        mockAI.embedResult = [[0.1, 0.2, 0.3]]
        let service = EmbeddingService(aiService: mockAI)

        let result = try await service.embed("hello world")
        #expect(result == [0.1, 0.2, 0.3])
        #expect(mockAI.embedCallCount == 1)
    }

    @Test("embed empty text throws emptyInput")
    func embed_emptyText_throwsEmptyInput() async {
        let service = EmbeddingService(aiService: MockAIService())
        await #expect(throws: EmbeddingError.self) {
            _ = try await service.embed("")
        }
    }

    @Test("embed whitespace-only throws emptyInput")
    func embed_whitespaceOnly_throwsEmptyInput() async {
        let service = EmbeddingService(aiService: MockAIService())
        await #expect(throws: EmbeddingError.self) {
            _ = try await service.embed("   \n\t  ")
        }
    }

    @Test("embed trims whitespace before sending")
    func embed_trimsWhitespace() async throws {
        let mockAI = MockAIService()
        mockAI.embedResult = [[1.0]]
        let service = EmbeddingService(aiService: mockAI)

        _ = try await service.embed("  hello  ")
        #expect(mockAI.lastEmbedTexts == ["hello"])
    }

    @Test("embed network error throws EmbeddingError")
    func embed_networkError_throwsEmbeddingError() async {
        let mockAI = MockAIService()
        mockAI.embedError = AIServiceError.networkError(
            NSError(domain: "test", code: -1)
        )
        let service = EmbeddingService(aiService: mockAI)

        await #expect(throws: EmbeddingError.self) {
            _ = try await service.embed("hello")
        }
    }

    // MARK: - Batch Embed

    @Test("embedBatch success returns vectors")
    func embedBatch_success() async throws {
        let mockAI = MockAIService()
        mockAI.embedResult = [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]]
        let service = EmbeddingService(aiService: mockAI)

        let result = try await service.embedBatch(["a", "b", "c"])
        #expect(result.count == 3)
    }

    @Test("embedBatch filters empty strings with zero vectors")
    func embedBatch_filtersEmptyStrings() async throws {
        let mockAI = MockAIService()
        mockAI.embedResult = [[1.0, 2.0]]
        let service = EmbeddingService(aiService: mockAI)

        let result = try await service.embedBatch(["hello", "", "world"])
        #expect(result.count == 3)
        // The empty string slot should be a zero vector
        #expect(result[1] == Array(repeating: Float(0.0), count: EmbeddingService.embeddingDimension))
    }

    @Test("embedBatch all empty returns zero vectors")
    func embedBatch_allEmpty_returnsZeroVectors() async throws {
        let service = EmbeddingService(aiService: MockAIService())
        let result = try await service.embedBatch(["", "  ", "\n"])
        #expect(result.count == 3)
        for vec in result {
            #expect(vec == Array(repeating: Float(0.0), count: EmbeddingService.embeddingDimension))
        }
    }

    @Test("embedBatch network error returns zero vectors as fallback")
    func embedBatch_networkError_returnsZeroVectors() async throws {
        let mockAI = MockAIService()
        mockAI.embedError = AIServiceError.networkError(
            NSError(domain: "test", code: -1)
        )
        let service = EmbeddingService(aiService: mockAI)

        let result = try await service.embedBatch(["hello", "world"])
        #expect(result.count == 2)
        for vec in result {
            #expect(vec == Array(repeating: Float(0.0), count: EmbeddingService.embeddingDimension))
        }
    }

    // MARK: - Cosine Similarity

    @Test("cosineSimilarity identical vectors returns ~1.0")
    func cosineSimilarity_identicalVectors_returns1() async {
        let service = EmbeddingService(aiService: MockAIService())
        let vec: [Float] = [1.0, 0.0, 0.0]
        let result = await service.cosineSimilarity(vec, vec)
        #expect(abs(result - 1.0) < 0.001)
    }

    @Test("cosineSimilarity orthogonal vectors returns ~0.0")
    func cosineSimilarity_orthogonalVectors_returns0() async {
        let service = EmbeddingService(aiService: MockAIService())
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [0.0, 1.0, 0.0]
        let result = await service.cosineSimilarity(a, b)
        #expect(abs(result) < 0.001)
    }

    @Test("cosineSimilarity opposite vectors returns ~-1.0")
    func cosineSimilarity_oppositeVectors_returnsNeg1() async {
        let service = EmbeddingService(aiService: MockAIService())
        let a: [Float] = [1.0, 0.0]
        let b: [Float] = [-1.0, 0.0]
        let result = await service.cosineSimilarity(a, b)
        #expect(abs(result - (-1.0)) < 0.001)
    }

    @Test("cosineSimilarity empty vectors returns 0")
    func cosineSimilarity_emptyVectors_returns0() async {
        let service = EmbeddingService(aiService: MockAIService())
        let result = await service.cosineSimilarity([], [])
        #expect(result == 0)
    }

    @Test("cosineSimilarity mismatched lengths returns 0")
    func cosineSimilarity_mismatchedLengths_returns0() async {
        let service = EmbeddingService(aiService: MockAIService())
        let result = await service.cosineSimilarity([1.0, 2.0], [1.0])
        #expect(result == 0)
    }

    // MARK: - Static Properties

    @Test("embedding dimension is 384")
    func embeddingDimension_is384() {
        #expect(EmbeddingService.embeddingDimension == 384)
    }

    @Test("embedding version is 2")
    func embeddingVersion_is2() {
        #expect(EmbeddingService.embeddingVersion == 2)
    }
}
