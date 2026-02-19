//
//  AIServiceProtocol.swift
//  Reef
//
//  Protocol for AIService to enable dependency injection in tests.
//

import Foundation

protocol AIServiceProtocol: Sendable {
    /// Generate text embeddings
    func embed(
        texts: [String],
        normalize: Bool,
        useMock: Bool
    ) async throws -> [[Float]]
}

/// Default parameter values as extension
extension AIServiceProtocol {
    func embed(texts: [String], normalize: Bool = true, useMock: Bool = false) async throws -> [[Float]] {
        try await embed(texts: texts, normalize: normalize, useMock: useMock)
    }
}
