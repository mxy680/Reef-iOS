//
//  QuestionExtractionService.swift
//  Reef
//
//  Service for extracting questions from assignment PDFs via server API.
//

import Foundation

// MARK: - API Models

struct ReconstructProblem: Codable {
    let number: Int
    let label: String
    let pdf_base64: String
}

struct ReconstructSplitResponse: Codable {
    let problems: [ReconstructProblem]
    let total_problems: Int
    let page_count: Int
}

// MARK: - Error Types

enum QuestionExtractionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData
    case fileReadError
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
        case .fileReadError:
            return "Failed to read PDF file"
        case .fileWriteError:
            return "Failed to save extracted question"
        }
    }
}

// MARK: - Extraction Status

enum ExtractionJobStatus: String {
    case processing
    case completed
    case failed
}

// MARK: - QuestionExtractionService

/// Service for extracting questions from assignment PDFs
actor QuestionExtractionService {
    static let shared = QuestionExtractionService()

    private let baseURL = "https://api.studyreef.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600  // 10 minutes for reconstruction pipeline
        config.timeoutIntervalForResource = 660  // 11 minutes total
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Extract questions from a PDF file by sending it to the reconstruction server
    /// - Parameters:
    ///   - fileURL: URL to the PDF file
    ///   - noteID: UUID of the note
    ///   - onStatusUpdate: Callback for status updates
    /// - Returns: Array of extracted questions saved locally
    func extractQuestions(
        fileURL: URL,
        noteID: UUID,
        onStatusUpdate: ((ExtractionJobStatus) -> Void)? = nil
    ) async throws -> [ExtractedQuestion] {
        // Read PDF file
        guard let pdfData = try? Data(contentsOf: fileURL) else {
            throw QuestionExtractionError.fileReadError
        }

        onStatusUpdate?(.processing)

        // Build multipart/form-data request
        guard let url = URL(string: baseURL + "/ai/reconstruct?split=true") else {
            throw QuestionExtractionError.invalidURL
        }

        let boundary = UUID().uuidString
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        // Send request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw QuestionExtractionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuestionExtractionError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractErrorMessage(from: data)
            throw QuestionExtractionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Decode response
        let splitResponse: ReconstructSplitResponse
        do {
            splitResponse = try JSONDecoder().decode(ReconstructSplitResponse.self, from: data)
        } catch {
            throw QuestionExtractionError.decodingError(error)
        }

        // Save each problem PDF locally
        var extractedQuestions: [ExtractedQuestion] = []
        for problem in splitResponse.problems {
            let savedQuestion = try saveQuestionPDF(problem: problem, noteID: noteID)
            extractedQuestions.append(savedQuestion)
        }

        onStatusUpdate?(.completed)
        return extractedQuestions
    }

    // MARK: - Private Helpers

    private func extractErrorMessage(from data: Data) -> String {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
           let detail = errorDict["detail"] {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    private func saveQuestionPDF(problem: ReconstructProblem, noteID: UUID) throws -> ExtractedQuestion {
        guard let pdfData = Data(base64Encoded: problem.pdf_base64) else {
            throw QuestionExtractionError.fileWriteError
        }

        let fileName = "question_\(problem.number - 1).pdf"  // 0-based file naming

        do {
            try FileStorageService.shared.saveQuestionFile(
                data: pdfData,
                questionSetID: noteID,
                fileName: fileName
            )
        } catch {
            throw QuestionExtractionError.fileWriteError
        }

        return ExtractedQuestion(
            questionNumber: problem.number,  // 1-based for display
            pdfFileName: fileName
        )
    }
}
