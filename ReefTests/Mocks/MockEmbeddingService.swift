//
//  MockEmbeddingService.swift
//  ReefTests
//

import Foundation
@testable import Reef

final class MockEmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {
    var isAvailableResult = true
    var embedResult: [Float] = Array(repeating: 0.5, count: 384)
    var embedBatchResult: [[Float]] = []
    var embedError: Error? = nil
    var embedCallCount = 0

    func isAvailable() -> Bool { isAvailableResult }

    func embed(_ text: String) async throws -> [Float] {
        embedCallCount += 1
        if let error = embedError { throw error }
        return embedResult
    }

    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        embedCallCount += 1
        if let error = embedError { throw error }
        if !embedBatchResult.isEmpty { return embedBatchResult }
        return texts.map { _ in embedResult }
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = sqrt(na) * sqrt(nb)
        return denom > 0 ? dot / denom : 0
    }
}
