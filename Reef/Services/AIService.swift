//
//  AIService.swift
//  Reef
//
//  Networking service for AI endpoints on Reef-Server.
//  Handles feedback, quiz generation, and chat with multi-provider support.
//

import Foundation
import SwiftUI

// MARK: - Server Models

/// Context chunk for server API
struct ServerContextChunk: Codable {
    let text: String
    let source_type: String
    let source_id: String
    let heading: String?
    let page_number: Int?
    let similarity: Float
}

/// RAG context for server API
struct ServerRAGContext: Codable {
    let chunks: [ServerContextChunk]
    let query: String

    /// Whether any context was found
    var hasContext: Bool { !chunks.isEmpty }
}

/// Image data for server API
struct ServerImageData: Codable {
    let data: String
    let mime_type: String
}

/// AI preferences for server API
struct ServerAIPreferences: Codable {
    let model: String
    let detail_level: String
    let language: String
}

// MARK: - Feedback Models

struct AIFeedbackRequest: Codable {
    let images: [ServerImageData]
    let prompt: String?
    let rag_context: ServerRAGContext?
    let preferences: ServerAIPreferences
}

struct AIFeedbackResponse: Codable {
    let feedback: String
    let detected_content: String?
    let model: String
    let provider: String
    let mode: String
}

// MARK: - Quiz Models

struct AIQuizConfigRequest: Codable {
    let count: Int
    let types: [String]
    let difficulty: String
}

struct AIQuizRequest: Codable {
    let rag_context: ServerRAGContext
    let config: AIQuizConfigRequest
    let preferences: ServerAIPreferences
    let additional_instructions: String?
}

struct AIQuizOptionResponse: Codable {
    let label: String
    let text: String
}

struct AIQuizQuestionResponse: Codable {
    let id: String
    let type: String
    let question: String
    let options: [AIQuizOptionResponse]?
    let correct_answer: String
    let explanation: String
    let source_chunk_ids: [String]
}

struct AIQuizResponse: Codable {
    let questions: [AIQuizQuestionResponse]
    let model: String
    let provider: String
    let mode: String
}

// MARK: - Chat Models

struct AIChatMessageRequest: Codable {
    let role: String
    let content: String
}

struct AIChatRequest: Codable {
    let message: String
    let rag_context: ServerRAGContext?
    let conversation_history: [AIChatMessageRequest]
    let preferences: ServerAIPreferences
}

struct AISourceReferenceResponse: Codable {
    let source_id: String
    let source_type: String
    let heading: String?
    let relevance: Float
}

struct AIChatResponse: Codable {
    let message: String
    let sources: [AISourceReferenceResponse]
    let model: String
    let provider: String
    let mode: String
}

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

    // Configure your server URL here
    private let baseURL: String
    private let session: URLSession

    private init() {
        // Default to localhost for development
        // In production, this should be configured via environment or config file
        // Use Railway server for all builds
        self.baseURL = "https://reef-production-08bd.up.railway.app"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Feedback

    /// Get AI feedback on handwritten work
    /// - Parameters:
    ///   - images: Array of image data (PNG/JPEG as Data)
    ///   - prompt: Optional custom prompt or question
    ///   - context: Optional RAG context from course materials (use RAGService.getServerContext)
    ///   - useMock: Whether to use mock mode for testing
    /// - Returns: AIFeedbackResponse with AI feedback
    func feedback(
        images: [Data],
        prompt: String? = nil,
        context: ServerRAGContext? = nil,
        useMock: Bool = false
    ) async throws -> AIFeedbackResponse {
        let prefs = PreferencesManager.shared
        let model = prefs.handwritingModel
        let detailLevel = prefs.feedbackDetailLevel.lowercased()
        let language = languageCode(for: prefs.recognitionLanguage)

        let request = AIFeedbackRequest(
            images: images.map { imageData in
                ServerImageData(
                    data: imageData.base64EncodedString(),
                    mime_type: "image/png"
                )
            },
            prompt: prompt,
            rag_context: context,
            preferences: ServerAIPreferences(
                model: model,
                detail_level: detailLevel,
                language: language
            )
        )

        return try await post(
            endpoint: "/ai/feedback",
            body: request,
            responseType: AIFeedbackResponse.self,
            useMock: useMock
        )
    }

    // MARK: - Quiz Generation

    /// Generate quiz questions from course materials
    /// - Parameters:
    ///   - context: Server RAG context with course materials (use RAGService.getServerContext)
    ///   - count: Number of questions to generate
    ///   - types: Types of questions to include (e.g., ["multiple_choice", "true_false"])
    ///   - difficulty: Difficulty level ("easy", "medium", "hard")
    ///   - additionalInstructions: Optional instructions for the AI
    ///   - useMock: Whether to use mock mode for testing
    /// - Returns: AIQuizResponse with generated questions
    func generateQuiz(
        context: ServerRAGContext,
        count: Int = 5,
        types: [String] = ["multiple_choice"],
        difficulty: String = "medium",
        additionalInstructions: String? = nil,
        useMock: Bool = false
    ) async throws -> AIQuizResponse {
        let prefs = PreferencesManager.shared
        let model = prefs.reasoningModel

        let request = AIQuizRequest(
            rag_context: context,
            config: AIQuizConfigRequest(
                count: count,
                types: types,
                difficulty: difficulty
            ),
            preferences: ServerAIPreferences(
                model: model,
                detail_level: "balanced",
                language: "en"
            ),
            additional_instructions: additionalInstructions
        )

        return try await post(
            endpoint: "/ai/quiz",
            body: request,
            responseType: AIQuizResponse.self,
            useMock: useMock
        )
    }

    // MARK: - Chat

    /// Send a chat message with RAG context
    /// - Parameters:
    ///   - message: User's message
    ///   - context: Optional server RAG context (use RAGService.getServerContext)
    ///   - history: Previous messages in the conversation
    ///   - useMock: Whether to use mock mode for testing
    /// - Returns: AIChatResponse with AI's reply
    func chat(
        message: String,
        context: ServerRAGContext? = nil,
        history: [(role: String, content: String)] = [],
        useMock: Bool = false
    ) async throws -> AIChatResponse {
        let prefs = PreferencesManager.shared
        let model = prefs.reasoningModel
        let detailLevel = prefs.feedbackDetailLevel.lowercased()
        let language = languageCode(for: prefs.recognitionLanguage)

        let request = AIChatRequest(
            message: message,
            rag_context: context,
            conversation_history: history.map { AIChatMessageRequest(role: $0.role, content: $0.content) },
            preferences: ServerAIPreferences(
                model: model,
                detail_level: detailLevel,
                language: language
            )
        )

        return try await post(
            endpoint: "/ai/chat",
            body: request,
            responseType: AIChatResponse.self,
            useMock: useMock
        )
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

        let response = try await post(
            endpoint: "/ai/embed",
            body: request,
            responseType: AIEmbedResponse.self,
            useMock: useMock
        )

        return response.embeddings
    }

    // MARK: - Private Helpers

    private func post<T: Codable, R: Codable>(
        endpoint: String,
        body: T,
        responseType: R.Type,
        useMock: Bool
    ) async throws -> R {
        var urlString = baseURL + endpoint
        if useMock {
            urlString += "?mode=mock"
        }

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.noData
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            let message: String
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorDict["detail"] {
                message = detail
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(R.self, from: data)
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }

    private func languageCode(for language: String) -> String {
        switch language.lowercased() {
        case "spanish": return "es"
        case "french": return "fr"
        case "german": return "de"
        case "chinese": return "zh"
        case "japanese": return "ja"
        default: return "en"
        }
    }
}
