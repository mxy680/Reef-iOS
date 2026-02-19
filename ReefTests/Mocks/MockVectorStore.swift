//
//  MockVectorStore.swift
//  ReefTests
//

import Foundation
@testable import Reef

final class MockVectorStore: VectorStoreProtocol, @unchecked Sendable {
    var indexedChunks: [(chunks: [TextChunk], embeddings: [[Float]], courseId: UUID)] = []
    var searchResults: [VectorSearchResult] = []
    var searchError: Error? = nil
    var chunkCountResult = 0
    var deletedDocumentIds: [UUID] = []
    var deletedCourseIds: [UUID] = []

    func initialize() throws {}

    func index(chunks: [TextChunk], embeddings: [[Float]], courseId: UUID) throws {
        indexedChunks.append((chunks, embeddings, courseId))
    }

    func search(query queryEmbedding: [Float], courseId: UUID, topK: Int) throws -> [VectorSearchResult] {
        if let error = searchError { throw error }
        return Array(searchResults.prefix(topK))
    }

    func deleteDocument(documentId: UUID) throws {
        deletedDocumentIds.append(documentId)
    }

    func deleteCourse(courseId: UUID) throws {
        deletedCourseIds.append(courseId)
    }

    func deleteAllChunks() throws {
        indexedChunks = []
    }

    func chunkCount(forDocument documentId: UUID) throws -> Int {
        chunkCountResult
    }

    func close() {}
}
