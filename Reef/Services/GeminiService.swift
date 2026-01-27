//
//  GeminiService.swift
//  Reef
//
//  Actor-based service for interacting with Google's Gemini API
//

import Foundation

/// Actor-based service for Gemini API interactions
actor GeminiService {
    static let shared = GeminiService()

    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.0-flash"

    private init() {
        self.apiKey = Secrets.geminiAPIKey
    }

    // MARK: - Request/Response Types

    struct GeminiRequest: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig?

        struct Content: Encodable {
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String
        }

        struct GenerationConfig: Encodable {
            let responseMimeType: String?
            let temperature: Double?
        }
    }

    struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        let error: GeminiError?

        struct Candidate: Decodable {
            let content: Content
        }

        struct Content: Decodable {
            let parts: [Part]
        }

        struct Part: Decodable {
            let text: String
        }

        struct GeminiError: Decodable {
            let message: String
        }
    }

    // MARK: - Public API

    /// Generate content using Gemini
    /// - Parameters:
    ///   - prompt: The prompt to send to Gemini
    ///   - jsonOutput: If true, request JSON output format with temperature 0
    /// - Returns: The generated text response
    func generateContent(prompt: String, jsonOutput: Bool = false) async throws -> String {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let geminiRequest = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: jsonOutput ? .init(responseMimeType: "application/json", temperature: 0) : nil
        )

        request.httpBody = try JSONEncoder().encode(geminiRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.requestFailed
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let errorMessage = errorResponse.error?.message {
                throw GeminiError.apiError(errorMessage)
            }
            throw GeminiError.httpError(httpResponse.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let error = geminiResponse.error {
            throw GeminiError.apiError(error.message)
        }

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }

        return text
    }

    // MARK: - Errors

    enum GeminiError: Error, LocalizedError {
        case invalidURL
        case requestFailed
        case httpError(Int)
        case apiError(String)
        case noContent

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Gemini API URL"
            case .requestFailed:
                return "Gemini API request failed"
            case .httpError(let code):
                return "Gemini API returned HTTP \(code)"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            case .noContent:
                return "Gemini API returned no content"
            }
        }
    }
}
