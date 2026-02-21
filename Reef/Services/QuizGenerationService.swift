//
//  QuizGenerationService.swift
//  Reef
//
//  Service for generating quizzes via server API.
//

import Foundation

// MARK: - API Response Models

struct QuizQuestionAPIResponse: Codable {
    let number: Int
    let pdf_base64: String
    let topic: String?
}

// MARK: - Error Types

enum QuizGenerationError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData
    case fileWriteError

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
        case .fileWriteError:
            return "Failed to save quiz question"
        }
    }
}

// MARK: - QuizGenerationService

actor QuizGenerationService {
    static let shared = QuizGenerationService()

    private let baseURL = ServerConfig.baseURL
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for quiz generation
        config.timeoutIntervalForResource = 360
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Generate a quiz by sending configuration + RAG context to the server
    /// - Parameters:
    ///   - topic: Quiz topic
    ///   - difficulty: Difficulty level
    ///   - numberOfQuestions: Number of questions to generate
    ///   - ragContext: RAG-retrieved course content
    ///   - useGeneralKnowledge: Whether to allow questions beyond notes
    ///   - additionalNotes: Extra instructions
    ///   - questionTypes: Types of questions to include
    ///   - quizID: UUID to use for file storage
    /// - Returns: Array of QuizQuestionItems saved locally
    func generateQuiz(
        topic: String,
        difficulty: String,
        numberOfQuestions: Int,
        ragContext: String,
        useGeneralKnowledge: Bool,
        additionalNotes: String?,
        questionTypes: [String],
        quizID: UUID
    ) async throws -> [QuizQuestionItem] {
        // Build request
        guard let url = URL(string: baseURL + "/ai/generate-quiz") else {
            throw QuizGenerationError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "topic": topic,
            "difficulty": difficulty,
            "num_questions": numberOfQuestions,
            "rag_context": ragContext,
            "use_general_knowledge": useGeneralKnowledge,
            "additional_notes": additionalNotes as Any,
            "question_types": questionTypes,
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw QuizGenerationError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuizGenerationError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractErrorMessage(from: data)
            throw QuizGenerationError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Decode response
        let apiResponses: [QuizQuestionAPIResponse]
        do {
            apiResponses = try JSONDecoder().decode([QuizQuestionAPIResponse].self, from: data)
        } catch {
            throw QuizGenerationError.decodingError(error)
        }

        // Save each question PDF locally
        var questions: [QuizQuestionItem] = []
        for apiResponse in apiResponses {
            let saved = try saveQuestionPDF(apiResponse: apiResponse, quizID: quizID)
            questions.append(saved)
        }

        return questions
    }

    // MARK: - Private Helpers

    private func extractErrorMessage(from data: Data) -> String {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
           let detail = errorDict["detail"] {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    private func saveQuestionPDF(apiResponse: QuizQuestionAPIResponse, quizID: UUID) throws -> QuizQuestionItem {
        guard let pdfData = Data(base64Encoded: apiResponse.pdf_base64) else {
            throw QuizGenerationError.fileWriteError
        }

        let fileName = "question_\(apiResponse.number - 1).pdf"  // 0-based file naming

        do {
            try FileStorageService.shared.saveQuizQuestionFile(
                data: pdfData,
                quizID: quizID,
                fileName: fileName
            )
        } catch {
            throw QuizGenerationError.fileWriteError
        }

        return QuizQuestionItem(
            questionNumber: apiResponse.number,
            pdfFileName: fileName,
            topic: apiResponse.topic
        )
    }
}
