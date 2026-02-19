//
//  IntegrationTestHelpers.swift
//  ReefTests
//
//  Shared helpers for integration tests that hit the real local dev server.
//

import Foundation
import Testing

enum IntegrationTestConfig {
    static let baseURL = "http://localhost:8000"

    static func serverIsReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            let session = makeTestSession()
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 10
    config.timeoutIntervalForResource = 10
    return URLSession(configuration: config)
}

func makeTestSessionId() -> String {
    "test-\(UUID().uuidString)"
}

func cleanupTestSession(sessionId: String) async {
    guard let url = URL(string: "\(IntegrationTestConfig.baseURL)/api/strokes/disconnect") else {
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["session_id": sessionId])
    _ = try? await makeTestSession().data(for: request)
}
