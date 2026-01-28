//
//  QuestionRegion.swift
//  Reef
//
//  Data models for detected question regions in documents
//

import Foundation
import CoreGraphics

/// Status of question detection for a document
enum QuestionDetectionStatus: String, Codable {
    case pending         // Not yet processed
    case detecting       // Currently processing
    case completed       // Successfully detected regions
    case failed          // Detection failed
    case notApplicable   // Document doesn't appear to contain questions
}

/// Type of detected region
enum RegionType: String, Codable {
    case question        // A main question (1, 2, 3, etc.)
    case subquestion     // A sub-part of a question (a, b, c, i, ii, etc.)
}

/// A detected question region within a document page
struct QuestionRegion: Codable, Identifiable {
    let id: UUID
    let pageIndex: Int
    let regionType: RegionType       // question or subquestion
    let questionIdentifier: String?  // "1", "1-a", "2", etc.
    let questionText: String         // Full text content
    let textBoundingBox: CGRect      // Normalized coords (0-1), bottom-left origin (Vision format)
    let workspaceBoundingBox: CGRect? // Adjacent whitespace area for working
    let confidence: Double

    /// Combined bounding box covering both question text and workspace
    var totalBoundingBox: CGRect {
        guard let workspace = workspaceBoundingBox else {
            return textBoundingBox
        }
        return textBoundingBox.union(workspace)
    }

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        regionType: RegionType = .question,
        questionIdentifier: String?,
        questionText: String,
        textBoundingBox: CGRect,
        workspaceBoundingBox: CGRect?,
        confidence: Double
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.regionType = regionType
        self.questionIdentifier = questionIdentifier
        self.questionText = questionText
        self.textBoundingBox = textBoundingBox
        self.workspaceBoundingBox = workspaceBoundingBox
        self.confidence = confidence
    }
}

/// Container for all detected question regions in a document
struct DocumentQuestionRegions: Codable {
    let documentId: UUID
    let pageCount: Int
    let regions: [QuestionRegion]
    let detectedAt: Date

    init(documentId: UUID, pageCount: Int, regions: [QuestionRegion], detectedAt: Date = Date()) {
        self.documentId = documentId
        self.pageCount = pageCount
        self.regions = regions
        self.detectedAt = detectedAt
    }

    /// Find the region containing a given point on a specific page
    /// - Parameters:
    ///   - point: Normalized point (0-1) in Vision coordinates (bottom-left origin)
    ///   - pageIndex: The page index to search
    /// - Returns: The question region containing the point, if any
    func region(containing point: CGPoint, onPage pageIndex: Int) -> QuestionRegion? {
        return regions
            .filter { $0.pageIndex == pageIndex }
            .first { $0.totalBoundingBox.contains(point) }
    }

    /// Get all regions for a specific page
    func regions(forPage pageIndex: Int) -> [QuestionRegion] {
        return regions.filter { $0.pageIndex == pageIndex }
    }
}

/// Context about the currently active question for AI feedback
struct ActiveQuestionContext: Codable {
    let questionId: UUID
    let questionIdentifier: String?
    let questionText: String
    let pageIndex: Int

    init(from region: QuestionRegion) {
        self.questionId = region.id
        self.questionIdentifier = region.questionIdentifier
        self.questionText = region.questionText
        self.pageIndex = region.pageIndex
    }
}
