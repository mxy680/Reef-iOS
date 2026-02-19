//
//  VectorStoreTests.swift
//  ReefTests
//
//  Tests for VectorStore using temporary SQLite databases.
//

import Testing
@testable import Reef
import Foundation

@Suite("VectorStore", .serialized)
struct VectorStoreTests {

    /// Create a temp SQLite file for each test
    private func makeTempStore() async throws -> VectorStore {
        let tmpDir = FileManager.default.temporaryDirectory
        let dbPath = tmpDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        let store = VectorStore(dbPath: dbPath)
        try await store.initialize()
        return store
    }

    /// Create sample chunks
    private func sampleChunks(docId: UUID, count: Int = 3) -> [TextChunk] {
        (0..<count).map { i in
            TextChunk(
                text: "Sample text chunk number \(i) with enough content to be meaningful",
                documentId: docId,
                documentType: .note,
                position: i,
                pageNumber: 1,
                heading: "Section \(i)"
            )
        }
    }

    /// Create sample embeddings (384-dim)
    private func sampleEmbeddings(count: Int) -> [[Float]] {
        (0..<count).map { i in
            var vec = Array(repeating: Float(0), count: EmbeddingService.embeddingDimension)
            vec[i % vec.count] = 1.0  // One-hot at different positions
            return vec
        }
    }

    // MARK: - Initialize

    @Test("initialize creates database without error")
    func initialize_createsDatabase() async throws {
        let store = try await makeTempStore()
        await store.close()
    }

    // MARK: - Index & Search

    @Test("index then search finds chunks by similarity")
    func index_thenSearch_findsChunks() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId)
        let embeddings = sampleEmbeddings(count: chunks.count)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)

        let queryVec = embeddings[0]
        let results = try await store.search(query: queryVec, courseId: courseId, topK: 5)

        #expect(!results.isEmpty)
        #expect(results[0].similarity > 0.99)
        #expect(results[0].text == chunks[0].text)
        await store.close()
    }

    @Test("search respects topK limit")
    func search_respectsTopK() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 10)
        let embeddings = sampleEmbeddings(count: 10)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)

        let queryVec = Array(repeating: Float(0.1), count: EmbeddingService.embeddingDimension)
        let results = try await store.search(query: queryVec, courseId: courseId, topK: 3)

        #expect(results.count <= 3)
        await store.close()
    }

    @Test("search is scoped by courseId")
    func search_scopedByCourseId() async throws {
        let store = try await makeTempStore()
        let course1 = UUID()
        let course2 = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 1)
        let embeddings = sampleEmbeddings(count: 1)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: course1)

        let results = try await store.search(query: embeddings[0], courseId: course2, topK: 5)
        #expect(results.isEmpty)
        await store.close()
    }

    @Test("search results sorted by similarity descending")
    func search_resultsSortedBySimilarityDescending() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 5)
        let embeddings = sampleEmbeddings(count: 5)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)

        let queryVec = Array(repeating: Float(0.1), count: EmbeddingService.embeddingDimension)
        let results = try await store.search(query: queryVec, courseId: courseId, topK: 5)

        for i in 0..<(results.count - 1) {
            #expect(results[i].similarity >= results[i + 1].similarity)
        }
        await store.close()
    }

    // MARK: - Chunk Count & Mismatch

    @Test("index with chunk/embedding mismatch throws error")
    func index_chunkEmbeddingMismatch_throws() async throws {
        let store = try await makeTempStore()
        let chunks = sampleChunks(docId: UUID(), count: 3)
        let embeddings = sampleEmbeddings(count: 2) // Mismatch!

        await #expect(throws: VectorStoreError.self) {
            try await store.index(chunks: chunks, embeddings: embeddings, courseId: UUID())
        }
        await store.close()
    }

    // MARK: - Deletion

    @Test("deleteDocument removes only that document")
    func deleteDocument_removesOnlyThatDocument() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let doc1 = UUID()
        let doc2 = UUID()

        let chunks1 = sampleChunks(docId: doc1, count: 2)
        let chunks2 = sampleChunks(docId: doc2, count: 2)
        let emb1 = sampleEmbeddings(count: 2)
        let emb2 = sampleEmbeddings(count: 2)

        try await store.index(chunks: chunks1, embeddings: emb1, courseId: courseId)
        try await store.index(chunks: chunks2, embeddings: emb2, courseId: courseId)

        try await store.deleteDocument(documentId: doc1)

        let count1 = try await store.chunkCount(forDocument: doc1)
        #expect(count1 == 0)

        let count2 = try await store.chunkCount(forDocument: doc2)
        #expect(count2 == 2)
        await store.close()
    }

    @Test("deleteCourse removes all chunks for course")
    func deleteCourse_removesAllChunksForCourse() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 3)
        let embeddings = sampleEmbeddings(count: 3)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)
        try await store.deleteCourse(courseId: courseId)

        let count = try await store.chunkCount(forDocument: docId)
        #expect(count == 0)
        await store.close()
    }

    @Test("deleteAllChunks clears everything")
    func deleteAllChunks_clearsEverything() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 5)
        let embeddings = sampleEmbeddings(count: 5)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)
        try await store.deleteAllChunks()

        let count = try await store.chunkCount(forDocument: docId)
        #expect(count == 0)
        await store.close()
    }

    // MARK: - Chunk Count

    @Test("chunkCount returns correct count after indexing")
    func chunkCount_returnsCorrectCount() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunks = sampleChunks(docId: docId, count: 4)
        let embeddings = sampleEmbeddings(count: 4)

        try await store.index(chunks: chunks, embeddings: embeddings, courseId: courseId)

        let count = try await store.chunkCount(forDocument: docId)
        #expect(count == 4)
        await store.close()
    }

    @Test("chunkCount for unknown document returns 0")
    func chunkCount_unknownDocument_returns0() async throws {
        let store = try await makeTempStore()
        let count = try await store.chunkCount(forDocument: UUID())
        #expect(count == 0)
        await store.close()
    }

    // MARK: - Search Result Fields

    @Test("search preserves metadata in results")
    func search_preservesMetadata() async throws {
        let store = try await makeTempStore()
        let courseId = UUID()
        let docId = UUID()
        let chunk = TextChunk(
            text: "Specific text content for search result metadata test that is long enough",
            documentId: docId,
            documentType: .assignment,
            position: 0,
            pageNumber: 7,
            heading: "Test Heading"
        )
        var emb = Array(repeating: Float(0), count: EmbeddingService.embeddingDimension)
        emb[0] = 1.0

        try await store.index(chunks: [chunk], embeddings: [emb], courseId: courseId)
        let results = try await store.search(query: emb, courseId: courseId)

        let result = try #require(results.first)
        #expect(result.documentId == docId)
        #expect(result.documentType == .assignment)
        #expect(result.pageNumber == 7)
        #expect(result.heading == "Test Heading")
        #expect(result.text.contains("Specific text content"))
        await store.close()
    }
}
