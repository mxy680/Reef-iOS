//
//  VectorStoreProtocol.swift
//  Reef
//

import Foundation

protocol VectorStoreProtocol: Sendable {
    func initialize() async throws
    func index(chunks: [TextChunk], embeddings: [[Float]], courseId: UUID) async throws
    func search(query queryEmbedding: [Float], courseId: UUID, topK: Int) async throws -> [VectorSearchResult]
    func deleteDocument(documentId: UUID) async throws
    func deleteCourse(courseId: UUID) async throws
    func deleteAllChunks() async throws
    func chunkCount(forDocument documentId: UUID) async throws -> Int
    func close() async
}
