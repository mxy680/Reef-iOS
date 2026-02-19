//
//  AIServiceTests.swift
//  ReefTests
//
//  Integration tests for AIService that hit the real local dev server.
//  Requires the Reef-Server running at http://localhost:8000.
//

import Testing
import Foundation
@testable import Reef

@Suite("AIService Integration", .serialized)
struct AIServiceIntegrationTests {

    @MainActor
    private func makeService() -> AIService {
        AIService(baseURL: "http://localhost:8000")
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }

    // MARK: - Tests

    @Test("embed single text returns 384-dim vector")
    func embedSingleTextReturns384DimVector() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: ["hello world"])

        #expect(result.count == 1)
        #expect(result[0].count == 384)
    }

    @Test("embed batch returns correct count")
    func embedBatchReturnsCorrectCount() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: ["hello", "world", "test"])

        #expect(result.count == 3)
        for vector in result {
            #expect(vector.count == 384)
        }
    }

    @Test("embed with normalize returns unit vectors")
    func embedWithNormalizeReturnsUnitVectors() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: ["normalization test"], normalize: true)

        #expect(result.count == 1)
        let vector = result[0]
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        #expect(abs(norm - 1.0) < 0.01)
    }

    @Test("embed with mock mode returns fast response")
    func embedWithMockModeReturnsFastResponse() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: ["mock mode test"], useMock: true)

        #expect(result.count == 1)
    }

    @Test("embed empty text array")
    func embedEmptyTextArray() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        do {
            let result = try await service.embed(texts: [])
            #expect(result.isEmpty)
        } catch {
            // Server may reject empty array — either outcome is acceptable
        }
    }

    @Test("embed very long text succeeds")
    func embedVeryLongTextSucceeds() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let longText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 112)
        #expect(longText.count >= 5000)

        let result = try await service.embed(texts: [longText])

        #expect(result.count == 1)
        #expect(result[0].count == 384)
    }

    @Test("embed special characters")
    func embedSpecialCharacters() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: ["∫∑∏ 你好世界 αβγ √2 ≠ 3"])

        #expect(result.count == 1)
        #expect(result[0].count == 384)
    }

    @Test("cosine similarity of identical texts ≈ 1.0")
    func cosineSimilarityOfIdenticalTextsApproximatesOne() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let text = "the mitochondria is the powerhouse of the cell"
        let result = try await service.embed(texts: [text, text])

        #expect(result.count == 2)
        let similarity = cosineSimilarity(result[0], result[1])
        #expect(similarity > 0.99)
    }

    @Test("cosine similarity of unrelated texts < 0.5")
    func cosineSimilarityOfUnrelatedTextsIsLow() async throws {
        try #require(await IntegrationTestConfig.serverIsReachable(), "Server not available")
        let service = await makeService()

        let result = try await service.embed(texts: [
            "quantum physics equations",
            "chocolate cake recipe"
        ])

        #expect(result.count == 2)
        let similarity = cosineSimilarity(result[0], result[1])
        #expect(similarity < 0.5)
    }
}
