//
//  AIService.swift
//  Reef
//
//  Networking service for AI endpoints on Reef-Server.
//

import Foundation

// MARK: - Embed Models

struct AIEmbedRequest: Codable {
    let texts: [String]
    let normalize: Bool
}

struct AIEmbedResponse: Codable {
    let embeddings: [[Float]]
    let model: String
    let dimensions: Int
    let count: Int
    let mode: String
}

// MARK: - Error Types

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}

// MARK: - AIService

/// Service for communicating with the Reef-Server AI endpoints
@MainActor
class AIService {
    static let shared = AIService()

    private let baseURL = "https://mxy680--reef-server-reefserver-web-app.modal.run"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Embeddings

    /// Generate text embeddings using the server's MiniLM model
    /// - Parameters:
    ///   - texts: Array of texts to embed
    ///   - normalize: Whether to L2-normalize the embeddings (default true)
    ///   - useMock: Whether to use mock mode for testing
    /// - Returns: Array of 384-dimensional embedding vectors
    func embed(
        texts: [String],
        normalize: Bool = true,
        useMock: Bool = false
    ) async throws -> [[Float]] {
        let request = AIEmbedRequest(
            texts: texts,
            normalize: normalize
        )

        var urlString = baseURL + "/ai/embed"
        if useMock {
            urlString += "?mode=mock"
        }

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message: String
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorDict["detail"] {
                message = detail
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let embedResponse = try JSONDecoder().decode(AIEmbedResponse.self, from: data)
        return embedResponse.embeddings
    }
}
