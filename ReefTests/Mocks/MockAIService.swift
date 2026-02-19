//
//  MockAIService.swift
//  ReefTests
//

import Foundation
@testable import Reef

final class MockAIService: AIServiceProtocol, @unchecked Sendable {
    var embedResult: [[Float]] = []
    var embedError: Error? = nil
    var embedCallCount = 0
    var lastEmbedTexts: [String]? = nil

    func embed(texts: [String], normalize: Bool, useMock: Bool) async throws -> [[Float]] {
        embedCallCount += 1
        lastEmbedTexts = texts
        if let error = embedError { throw error }
        return embedResult
    }
}
