//
//  RAGServiceTests.swift
//  ReefTests
//
//  Tests for RAGService with mocked EmbeddingService and VectorStore.
//

import Testing
@testable import Reef
import Foundation

@Suite("RAGService")
struct RAGServiceTests {

    private func makeService(
        embedding: MockEmbeddingService = MockEmbeddingService(),
        vectorStore: MockVectorStore = MockVectorStore()
    ) -> (RAGService, MockEmbeddingService, MockVectorStore) {
        let service = RAGService(embeddingService: embedding, vectorStore: vectorStore)
        return (service, embedding, vectorStore)
    }

    // MARK: - Index Document

    @Test("indexDocument chunks and stores embeddings")
    func indexDocument_chunksAndStoresEmbeddings() async throws {
        let (service, mockEmb, mockVS) = makeService()
        let docId = UUID()
        let courseId = UUID()
        let text = String(repeating: "This is content for indexing. ", count: 20) // ~600 chars

        try await service.indexDocument(
            documentId: docId,
            documentType: .note,
            courseId: courseId,
            text: text
        )

        #expect(mockEmb.embedCallCount == 1)
        #expect(mockVS.indexedChunks.count == 1)
        #expect(mockVS.indexedChunks[0].courseId == courseId)
    }

    @Test("indexDocument short text skips indexing")
    func indexDocument_shortText_skipsIndexing() async throws {
        let (service, mockEmb, mockVS) = makeService()
        let text = "too short"

        try await service.indexDocument(
            documentId: UUID(),
            documentType: .note,
            courseId: UUID(),
            text: text
        )

        #expect(mockEmb.embedCallCount == 0)
        #expect(mockVS.indexedChunks.isEmpty)
    }

    @Test("indexDocument embedding unavailable skips")
    func indexDocument_embeddingUnavailable_skips() async throws {
        let mockEmb = MockEmbeddingService()
        mockEmb.isAvailableResult = false
        let (service, _, mockVS) = makeService(embedding: mockEmb)

        let text = String(repeating: "content ", count: 50)
        try await service.indexDocument(
            documentId: UUID(),
            documentType: .note,
            courseId: UUID(),
            text: text
        )

        #expect(mockVS.indexedChunks.isEmpty)
    }

    // MARK: - Get Context

    @Test("getContext returns formatted prompt with results")
    func getContext_returnsFormattedPrompt() async throws {
        let mockVS = MockVectorStore()
        mockVS.searchResults = [
            VectorSearchResult(
                id: "1", text: "Relevant chunk",
                documentId: UUID(), documentType: .note,
                pageNumber: 1, heading: "Intro",
                similarity: 0.85
            )
        ]
        let (service, _, _) = makeService(vectorStore: mockVS)

        let context = try await service.getContext(query: "test query", courseId: UUID())

        #expect(context.hasContext)
        #expect(context.chunkCount == 1)
        #expect(context.formattedPrompt.contains("Relevant chunk"))
        #expect(context.formattedPrompt.contains("course materials"))
    }

    @Test("getContext filters low similarity results")
    func getContext_filtersLowSimilarity() async throws {
        let mockVS = MockVectorStore()
        mockVS.searchResults = [
            VectorSearchResult(
                id: "1", text: "Good match",
                documentId: UUID(), documentType: .note,
                pageNumber: nil, heading: nil,
                similarity: 0.80
            ),
            VectorSearchResult(
                id: "2", text: "Bad match",
                documentId: UUID(), documentType: .note,
                pageNumber: nil, heading: nil,
                similarity: 0.10  // Below 0.15 threshold
            )
        ]
        let (service, _, _) = makeService(vectorStore: mockVS)

        let context = try await service.getContext(query: "test", courseId: UUID())

        #expect(context.chunkCount == 1)
        #expect(context.formattedPrompt.contains("Good match"))
        #expect(!context.formattedPrompt.contains("Bad match"))
    }

    @Test("getContext no results returns empty context")
    func getContext_noResults_returnsEmptyContext() async throws {
        let mockVS = MockVectorStore()
        mockVS.searchResults = []
        let (service, _, _) = makeService(vectorStore: mockVS)

        let context = try await service.getContext(query: "test", courseId: UUID())

        #expect(!context.hasContext)
        #expect(context.chunkCount == 0)
        #expect(context.formattedPrompt.isEmpty)
    }

    @Test("getContext embedding unavailable returns empty")
    func getContext_embeddingUnavailable_returnsEmpty() async throws {
        let mockEmb = MockEmbeddingService()
        mockEmb.isAvailableResult = false
        let (service, _, _) = makeService(embedding: mockEmb)

        let context = try await service.getContext(query: "test", courseId: UUID())

        #expect(!context.hasContext)
    }

    @Test("getContext respects token budget")
    func getContext_respectsTokenBudget() async throws {
        let mockVS = MockVectorStore()
        let largeText = String(repeating: "x", count: 2000)
        mockVS.searchResults = (0..<10).map { i in
            VectorSearchResult(
                id: "\(i)", text: largeText,
                documentId: UUID(), documentType: .note,
                pageNumber: nil, heading: nil,
                similarity: 0.9
            )
        }
        let (service, _, _) = makeService(vectorStore: mockVS)

        // With default maxTokens=2000, chars budget is ~8000
        // Each chunk is 2000 chars, so only ~3-4 should fit
        let context = try await service.getContext(query: "test", courseId: UUID())

        #expect(context.chunkCount < 10)
        #expect(context.chunkCount >= 1)
    }

    // MARK: - Deletion

    @Test("deleteDocument delegates to vector store")
    func deleteDocument_delegatesToVectorStore() async throws {
        let mockVS = MockVectorStore()
        let (service, _, _) = makeService(vectorStore: mockVS)
        let docId = UUID()

        try await service.deleteDocument(documentId: docId)

        #expect(mockVS.deletedDocumentIds == [docId])
    }

    @Test("deleteCourse delegates to vector store")
    func deleteCourse_delegatesToVectorStore() async throws {
        let mockVS = MockVectorStore()
        let (service, _, _) = makeService(vectorStore: mockVS)
        let courseId = UUID()

        try await service.deleteCourse(courseId: courseId)

        #expect(mockVS.deletedCourseIds == [courseId])
    }

    // MARK: - Status

    @Test("isDocumentIndexed true when chunks exist")
    func isDocumentIndexed_trueWhenChunksExist() async throws {
        let mockVS = MockVectorStore()
        mockVS.chunkCountResult = 5
        let (service, _, _) = makeService(vectorStore: mockVS)

        let indexed = await service.isDocumentIndexed(documentId: UUID())
        #expect(indexed == true)
    }

    @Test("isDocumentIndexed false when no chunks")
    func isDocumentIndexed_falseWhenNoChunks() async throws {
        let mockVS = MockVectorStore()
        mockVS.chunkCountResult = 0
        let (service, _, _) = makeService(vectorStore: mockVS)

        let indexed = await service.isDocumentIndexed(documentId: UUID())
        #expect(indexed == false)
    }
}
