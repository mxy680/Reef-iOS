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
            let responseSchema: JSONSchema?
            let temperature: Double?
        }
    }

    /// JSON Schema for structured outputs (uses class to allow recursive definitions)
    final class JSONSchema: Encodable {
        let type: String
        let properties: [String: JSONSchema]?
        let items: JSONSchema?
        let required: [String]?
        let `enum`: [String]?
        let description: String?

        init(
            type: String,
            properties: [String: JSONSchema]? = nil,
            items: JSONSchema? = nil,
            required: [String]? = nil,
            enumValues: [String]? = nil,
            description: String? = nil
        ) {
            self.type = type
            self.properties = properties
            self.items = items
            self.required = required
            self.`enum` = enumValues
            self.description = description
        }

        /// Convenience for string type
        static var string: JSONSchema { JSONSchema(type: "string") }

        /// Convenience for integer type
        static var integer: JSONSchema { JSONSchema(type: "integer") }

        /// Convenience for array of items
        static func array(of items: JSONSchema) -> JSONSchema {
            JSONSchema(type: "array", items: items)
        }

        /// Convenience for enum strings
        static func `enum`(_ values: [String]) -> JSONSchema {
            JSONSchema(type: "string", enumValues: values)
        }

        /// Convenience for object with properties
        static func object(_ properties: [String: JSONSchema], required: [String]? = nil) -> JSONSchema {
            JSONSchema(type: "object", properties: properties, required: required)
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
    ///   - schema: Optional JSON schema for structured outputs
    /// - Returns: The generated text response
    func generateContent(prompt: String, jsonOutput: Bool = false, schema: JSONSchema? = nil) async throws -> String {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let generationConfig: GeminiRequest.GenerationConfig?
        if let schema = schema {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: schema, temperature: 0)
        } else if jsonOutput {
            generationConfig = .init(responseMimeType: "application/json", responseSchema: nil, temperature: 0)
        } else {
            generationConfig = nil
        }

        let geminiRequest = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: generationConfig
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
