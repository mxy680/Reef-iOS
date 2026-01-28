//
//  QuestionRegionDetector.swift
//  Reef
//
//  Actor-based service using Apple Vision framework and Gemini LLM to detect question bounding boxes in documents.
//  Uses a two-pass approach: OCR all pages first, then single LLM call to group questions across pages.
//

import Vision
import UIKit
import PDFKit

// MARK: - Internal Data Structures

/// Vision observation with page context
private struct PagedObservation {
    let observation: VNRecognizedTextObservation
    let pageIndex: Int
}

/// Text observation data sent to LLM (includes page info for multi-page documents)
private struct TextObservation: Codable {
    let id: Int
    let page: Int
    let text: String
    let y: Double  // Normalized Y position (0-1, higher = top of page)
}

/// Question grouping returned by LLM
private struct QuestionGrouping: Codable {
    let type: String           // "question" or "subquestion"
    let questionId: String     // e.g., "1", "1-a", "2", "2-b"
    let questionText: String   // First line or summary of content
    let observationIds: [Int]
}

/// LLM response structure
private struct LLMResponse: Codable {
    let questions: [QuestionGrouping]
}

/// Actor-based service for detecting question regions in documents using Vision OCR and Gemini LLM
actor QuestionRegionDetector {
    static let shared = QuestionRegionDetector()

    private init() {}

    // MARK: - Public API

    /// Detect question regions in a document
    /// - Parameter url: URL to the document file (PDF or image)
    /// - Returns: Detected question regions, or nil if detection failed
    func detectQuestions(in url: URL) async -> DocumentQuestionRegions? {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return await detectQuestionsInPDF(at: url)
        case "jpg", "jpeg", "png", "heic", "tiff", "gif":
            return await detectQuestionsInImage(at: url)
        default:
            return nil
        }
    }

    // MARK: - PDF Processing (Two-Pass Approach)

    private func detectQuestionsInPDF(at url: URL) async -> DocumentQuestionRegions? {
        guard let document = PDFDocument(url: url) else { return nil }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return nil }

        // PASS 1: OCR all pages in parallel
        let allPagedObservations = await withTaskGroup(of: (Int, [VNRecognizedTextObservation]).self) { group in
            for pageIndex in 0..<pageCount {
                group.addTask {
                    let observations = await self.ocrPage(document: document, pageIndex: pageIndex)
                    return (pageIndex, observations)
                }
            }

            var results: [(Int, [VNRecognizedTextObservation])] = []
            for await result in group {
                results.append(result)
            }

            // Sort by page index to maintain order
            return results.sorted { $0.0 < $1.0 }
        }

        // Flatten into PagedObservation array
        var pagedObservations: [PagedObservation] = []
        for (pageIndex, observations) in allPagedObservations {
            for obs in observations {
                pagedObservations.append(PagedObservation(observation: obs, pageIndex: pageIndex))
            }
        }

        guard !pagedObservations.isEmpty else { return nil }

        // PASS 2: Single LLM call to group all observations into questions
        let regions = await groupAllObservationsIntoQuestions(pagedObservations)

        guard !regions.isEmpty else { return nil }

        // Sort regions by page index, then by Y position (top to bottom)
        let sortedRegions = regions.sorted { lhs, rhs in
            if lhs.pageIndex != rhs.pageIndex {
                return lhs.pageIndex < rhs.pageIndex
            }
            return lhs.textBoundingBox.origin.y > rhs.textBoundingBox.origin.y
        }

        print("[QuestionDetector] Detected \(sortedRegions.count) question region(s) in PDF")

        return DocumentQuestionRegions(
            documentId: UUID(),
            pageCount: pageCount,
            regions: sortedRegions
        )
    }

    /// OCR a single PDF page
    private func ocrPage(document: PDFDocument, pageIndex: Int) async -> [VNRecognizedTextObservation] {
        guard let page = document.page(at: pageIndex) else { return [] }

        let scale: CGFloat = 2.0
        let pageRect = page.bounds(for: .mediaBox)
        let renderSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }

        guard let cgImage = image.cgImage else { return [] }
        return await performTextRecognition(on: cgImage)
    }

    // MARK: - Image Processing

    private func detectQuestionsInImage(at url: URL) async -> DocumentQuestionRegions? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            return nil
        }

        let observations = await performTextRecognition(on: cgImage)
        guard !observations.isEmpty else { return nil }

        // Wrap as paged observations (single page)
        let pagedObservations = observations.map { PagedObservation(observation: $0, pageIndex: 0) }

        let regions = await groupAllObservationsIntoQuestions(pagedObservations)
        guard !regions.isEmpty else { return nil }

        print("[QuestionDetector] Detected \(regions.count) question(s) in image")

        return DocumentQuestionRegions(
            documentId: UUID(),
            pageCount: 1,
            regions: regions
        )
    }

    // MARK: - Vision Text Recognition

    private func performTextRecognition(on cgImage: CGImage) async -> [VNRecognizedTextObservation] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: observations)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - LLM-Based Question Grouping (Single Call for All Pages)

    private func groupAllObservationsIntoQuestions(_ pagedObservations: [PagedObservation]) async -> [QuestionRegion] {
        guard !pagedObservations.isEmpty else { return [] }

        // Sort by page, then by Y position (top to bottom within each page)
        let sorted = pagedObservations.sorted { lhs, rhs in
            if lhs.pageIndex != rhs.pageIndex {
                return lhs.pageIndex < rhs.pageIndex
            }
            return lhs.observation.boundingBox.origin.y > rhs.observation.boundingBox.origin.y
        }

        // Build input for LLM with page context
        var textObservations: [TextObservation] = []
        for (index, paged) in sorted.enumerated() {
            guard let text = paged.observation.topCandidates(1).first?.string else { continue }
            textObservations.append(TextObservation(
                id: index,
                page: paged.pageIndex + 1,  // 1-indexed for LLM readability
                text: text.trimmingCharacters(in: .whitespaces),
                y: paged.observation.boundingBox.origin.y
            ))
        }

        guard !textObservations.isEmpty else { return [] }

        // Single LLM call for all observations
        do {
            let groupings = try await callLLMForGrouping(textObservations)
            return createRegions(from: groupings, sortedObservations: sorted)
        } catch {
            print("[QuestionDetector] LLM grouping failed: \(error)")
            return []
        }
    }

    private func callLLMForGrouping(_ observations: [TextObservation], retryCount: Int = 0) async throws -> [QuestionGrouping] {
        let maxRetries = 3
        let baseDelaySeconds: Double = 2.0

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let observationsJSON = try encoder.encode(observations)
        let observationsString = String(data: observationsJSON, encoding: .utf8) ?? "[]"

        // Determine if multi-page
        let pageNumbers = Set(observations.map { $0.page })
        let isMultiPage = pageNumbers.count > 1

        let prompt = """
        Detect questions and subquestions in this document. Each OCR item has id, page, text, y position.
        \(isMultiPage ? "Questions may span pages." : "")

        Input: \(observationsString)

        RULES:
        1. "question" = main numbered questions (1, 2, 3, Problem 1, etc.). Set questionId to "1", "2", "3", etc.
        2. "subquestion" = sub-parts (a, b, c, i, ii). Set questionId to "1-a", "1-b", "2-a", etc.
        3. Each question/subquestion gets its OWN entry - never combine multiple questions
        4. INCLUDE in the question's bounding box:
           - The question/problem statement
           - Examples with FULL content (Input, Output, Explanation sections)
           - Given values, constants, formulas, definitions
           - Notes, hints, bullet points that are part of the problem
        5. STOP the bounding box when you see:
           - Text that looks like a SOLUTION or ANSWER (solving the problem, not stating it)
           - Unstructured text that doesn't follow the document's formatting
           - Text that explains HOW to solve rather than WHAT to solve
           - Variables being computed/derived rather than given
           - Phrases like "We will...", "First...", "The answer is...", "Therefore..."
        6. EXCLUDE: page numbers, headers, footers, document titles
        """

        // Define the response schema for structured output
        let questionSchema = GeminiService.JSONSchema.object([
            "type": .enum(["question", "subquestion"]),
            "questionId": .string,
            "questionText": .string,
            "observationIds": .array(of: .integer)
        ], required: ["type", "questionId", "questionText", "observationIds"])

        let responseSchema = GeminiService.JSONSchema.object([
            "questions": .array(of: questionSchema)
        ], required: ["questions"])

        do {
            let response = try await GeminiService.shared.generateContent(
                prompt: prompt,
                schema: responseSchema
            )
            let data = Data(response.utf8)
            let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
            return llmResponse.questions
        } catch let error as GeminiService.GeminiError {
            // Check if this is a rate limit error and we can retry
            if case .apiError(let message) = error,
               message.lowercased().contains("resource exhausted") || message.lowercased().contains("rate limit"),
               retryCount < maxRetries {
                let delay = baseDelaySeconds * pow(2.0, Double(retryCount))
                print("[QuestionDetector] Rate limited, retrying in \(delay)s (attempt \(retryCount + 1)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await callLLMForGrouping(observations, retryCount: retryCount + 1)
            }
            throw error
        }
    }

    /// Create QuestionRegion objects from LLM groupings
    /// For questions spanning multiple pages, creates one region per page
    private func createRegions(
        from groupings: [QuestionGrouping],
        sortedObservations: [PagedObservation]
    ) -> [QuestionRegion] {
        var regions: [QuestionRegion] = []

        for grouping in groupings {
            // Get all observations for this question
            let relevantPaged = grouping.observationIds.compactMap { id -> PagedObservation? in
                guard id >= 0 && id < sortedObservations.count else { return nil }
                return sortedObservations[id]
            }

            guard !relevantPaged.isEmpty else { continue }

            // Determine region type from LLM response
            let regionType: RegionType = grouping.type.lowercased() == "subquestion" ? .subquestion : .question

            // Group observations by page
            let observationsByPage = Dictionary(grouping: relevantPaged) { $0.pageIndex }

            // Create one region per page for this question
            for (pageIndex, pageObservations) in observationsByPage {
                let visionObservations = pageObservations.map { $0.observation }

                // Calculate union bounding box for this page
                var minX = CGFloat.greatestFiniteMagnitude
                var minY = CGFloat.greatestFiniteMagnitude
                var maxX = -CGFloat.greatestFiniteMagnitude
                var maxY = -CGFloat.greatestFiniteMagnitude
                var totalConfidence: Double = 0

                for obs in visionObservations {
                    let box = obs.boundingBox
                    minX = min(minX, box.minX)
                    minY = min(minY, box.minY)
                    maxX = max(maxX, box.maxX)
                    maxY = max(maxY, box.maxY)
                    if let confidence = obs.topCandidates(1).first?.confidence {
                        totalConfidence += Double(confidence)
                    }
                }

                regions.append(QuestionRegion(
                    pageIndex: pageIndex,
                    regionType: regionType,
                    questionIdentifier: grouping.questionId,
                    questionText: grouping.questionText,
                    textBoundingBox: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
                    workspaceBoundingBox: nil,
                    confidence: totalConfidence / Double(visionObservations.count)
                ))
            }
        }

        return regions
    }
}
