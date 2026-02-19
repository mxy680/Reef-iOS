//
//  EmbeddingServiceProtocol.swift
//  Reef
//

import Foundation

protocol EmbeddingServiceProtocol: Sendable {
    func isAvailable() -> Bool
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float
}
