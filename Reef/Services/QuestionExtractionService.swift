//
//  QuestionExtractionService.swift
//  Reef
//
//  Service for extracting questions from PDFs via the Reef-Server API.
//

import Foundation
import SwiftData

// MARK: - API Models

struct ExtractQuestionsRequest: Codable {
    let pdf_base64: String
    let note_id: String
}

struct QuestionData: Codable {
    let order_index: Int
    let question_number: String
    let pdf_base64: String
    let has_images: Bool
    let has_tables: Bool
}

struct ExtractQuestionsResponse: Codable {
    let questions: [QuestionData]
    let note_id: String
    let total_count: Int
}

// MARK: - Async Job API Models

struct SubmitExtractionRequest: Codable {
    let pdf_base64: String
    let note_id: String
}

struct SubmitExtractionResponse: Codable {
    let job_id: String
    let status: String
}

struct JobStatusResponse: Codable {
    let job_id: String
    let status: String
    let error_message: String?
}

enum JobStatus: String {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - Error Types

enum QuestionExtractionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData
    case fileReadError(Error)
    case fileSaveError(Error)
    case jobFailed(message: String)
    case jobNotFound(jobID: String)
    case cancelled

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
        case .fileReadError(let error):
            return "Failed to read PDF file: \(error.localizedDescription)"
        case .fileSaveError(let error):
            return "Failed to save question file: \(error.localizedDescription)"
        case .jobFailed(let message):
            return "Extraction failed: \(message)"
        case .jobNotFound(let jobID):
            return "Job not found: \(jobID)"
        case .cancelled:
            return "Extraction was cancelled"
        }
    }
}

// MARK: - QuestionExtractionService

@MainActor
class QuestionExtractionService {
    static let shared = QuestionExtractionService()

    private let baseURL = "https://reef-production-08bd.up.railway.app"
    private let session: URLSession

    /// Polling interval for job status checks
    private let pollingInterval: Duration = .seconds(3)

    private init() {
        let config = URLSessionConfiguration.default
        // Submit can take time for large PDF uploads, but polling is fast
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Extracts questions from a note's PDF and creates a QuestionSet
    /// - Parameters:
    ///   - note: The note containing the PDF to extract from
    ///   - modelContext: SwiftData model context for persistence
    /// - Returns: The created QuestionSet
    func extractQuestions(
        from note: Note,
        modelContext: ModelContext
    ) async throws -> QuestionSet {
        // Check if a QuestionSet already exists for this note
        let noteID = note.id
        let descriptor = FetchDescriptor<QuestionSet>(
            predicate: #Predicate { $0.sourceNoteID == noteID }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            if existing.extractionStatus == .completed {
                return existing
            }
            // If extraction failed or is pending, delete and retry
            modelContext.delete(existing)
        }

        // Create new QuestionSet
        let questionSet = QuestionSet(sourceNoteID: note.id)
        questionSet.extractionStatus = .extracting
        modelContext.insert(questionSet)
        try modelContext.save()

        do {
            // Read PDF file
            let pdfURL = FileStorageService.shared.getFileURL(
                for: note.id,
                fileExtension: note.fileExtension
            )

            let pdfData: Data
            do {
                pdfData = try Data(contentsOf: pdfURL)
            } catch {
                throw QuestionExtractionError.fileReadError(error)
            }

            let pdfBase64 = pdfData.base64EncodedString()

            // Use async job API for extraction
            let response = try await extractQuestionsAsync(
                pdfBase64: pdfBase64,
                noteID: note.id.uuidString
            )

            print("[QuestionExtractionService] API returned \(response.total_count) questions")

            // Save question PDFs and create Question entities
            print("[QuestionExtractionService] Processing \(response.questions.count) questions...")
            for questionData in response.questions {
                print("[QuestionExtractionService] Processing question \(questionData.question_number), order_index: \(questionData.order_index)")
                let fileName = "question_\(questionData.order_index).pdf"

                // Decode and save PDF
                guard let pdfBytes = Data(base64Encoded: questionData.pdf_base64) else {
                    print("[QuestionExtractionService] Failed to decode base64 for question \(questionData.question_number)")
                    print("[QuestionExtractionService] Base64 length: \(questionData.pdf_base64.count), prefix: \(String(questionData.pdf_base64.prefix(100)))")
                    continue
                }
                print("[QuestionExtractionService] Decoded \(pdfBytes.count) bytes for question \(questionData.question_number)")

                do {
                    try FileStorageService.shared.saveQuestionFile(
                        data: pdfBytes,
                        questionSetID: questionSet.id,
                        fileName: fileName
                    )
                    print("[QuestionExtractionService] Saved file: \(fileName)")
                } catch {
                    print("[QuestionExtractionService] Failed to save file: \(error)")
                    throw QuestionExtractionError.fileSaveError(error)
                }

                // Create Question entity
                let question = Question(
                    questionSet: questionSet,
                    orderIndex: questionData.order_index,
                    fileName: fileName,
                    questionNumber: questionData.question_number,
                    hasImages: questionData.has_images,
                    hasTables: questionData.has_tables
                )
                modelContext.insert(question)
                questionSet.questions.append(question)
                print("[QuestionExtractionService] Created Question entity for \(questionData.question_number)")
            }

            // Update status
            questionSet.extractionStatus = .completed
            try modelContext.save()

            print("[QuestionExtractionService] Saved \(questionSet.questions.count) questions to QuestionSet")

            return questionSet

        } catch {
            // Mark as failed
            questionSet.extractionStatus = .failed
            questionSet.errorMessage = error.localizedDescription
            try? modelContext.save()
            throw error
        }
    }

    /// Gets an existing QuestionSet for a note, if available
    func getQuestionSet(for noteID: UUID, modelContext: ModelContext) -> QuestionSet? {
        let descriptor = FetchDescriptor<QuestionSet>(
            predicate: #Predicate { $0.sourceNoteID == noteID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Checks if a QuestionSet exists and is ready for a note
    func hasReadyQuestionSet(for noteID: UUID, modelContext: ModelContext) -> Bool {
        guard let questionSet = getQuestionSet(for: noteID, modelContext: modelContext) else {
            return false
        }
        return questionSet.isReady
    }

    // MARK: - Private Methods (Async Job API)

    /// Extract questions using the async job API with polling
    private func extractQuestionsAsync(
        pdfBase64: String,
        noteID: String
    ) async throws -> ExtractQuestionsResponse {
        // Submit the job
        let jobID = try await submitExtractionJob(pdfBase64: pdfBase64, noteID: noteID)
        print("[QuestionExtractionService] Submitted job: \(jobID)")

        // Poll until complete
        while true {
            try Task.checkCancellation()

            let status = try await getJobStatus(jobID: jobID)
            print("[QuestionExtractionService] Job \(jobID) status: \(status.status)")

            switch JobStatus(rawValue: status.status) {
            case .completed:
                return try await getJobResults(jobID: jobID)

            case .failed:
                throw QuestionExtractionError.jobFailed(
                    message: status.error_message ?? "Unknown error"
                )

            case .pending, .processing, .none:
                try await Task.sleep(for: pollingInterval)
            }
        }
    }

    /// Submit a job for extraction (returns immediately)
    private func submitExtractionJob(
        pdfBase64: String,
        noteID: String
    ) async throws -> String {
        let urlString = baseURL + "/ai/extract-questions/submit"

        guard let url = URL(string: urlString) else {
            throw QuestionExtractionError.invalidURL
        }

        let request = SubmitExtractionRequest(
            pdf_base64: pdfBase64,
            note_id: noteID
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

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
            let message = parseErrorMessage(from: data)
            throw QuestionExtractionError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            let submitResponse = try JSONDecoder().decode(SubmitExtractionResponse.self, from: data)
            return submitResponse.job_id
        } catch {
            throw QuestionExtractionError.decodingError(error)
        }
    }

    /// Check the status of a job
    private func getJobStatus(jobID: String) async throws -> JobStatusResponse {
        let urlString = baseURL + "/ai/extract-questions/\(jobID)/status"

        guard let url = URL(string: urlString) else {
            throw QuestionExtractionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

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

        if httpResponse.statusCode == 404 {
            throw QuestionExtractionError.jobNotFound(jobID: jobID)
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data)
            throw QuestionExtractionError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(JobStatusResponse.self, from: data)
        } catch {
            throw QuestionExtractionError.decodingError(error)
        }
    }

    /// Get the results of a completed job
    private func getJobResults(jobID: String) async throws -> ExtractQuestionsResponse {
        let urlString = baseURL + "/ai/extract-questions/\(jobID)/results"

        guard let url = URL(string: urlString) else {
            throw QuestionExtractionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

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
            let message = parseErrorMessage(from: data)
            throw QuestionExtractionError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(ExtractQuestionsResponse.self, from: data)
        } catch {
            throw QuestionExtractionError.decodingError(error)
        }
    }

    /// Parse error message from response data
    private func parseErrorMessage(from data: Data) -> String {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
           let detail = errorDict["detail"] {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
