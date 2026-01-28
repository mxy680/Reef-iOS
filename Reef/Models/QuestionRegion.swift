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

// MARK: - Question Grouping for Assignment Mode

/// A group of related questions (parent + subquestions) for assignment mode display
struct QuestionGroup: Identifiable {
    let id: String                      // e.g. "0-1" (pageIndex-identifier)
    let parentQuestion: QuestionRegion?
    let subquestions: [QuestionRegion]
    let pageIndex: Int
    let unionBoundingBox: CGRect        // Vision coords (normalized, bottom-left origin), padded

    /// All regions in visual top-to-bottom order: parent first, then subquestions
    /// sorted by Vision Y descending (higher Y = higher on page).
    var orderedRegions: [QuestionRegion] {
        var regions: [QuestionRegion] = []
        if let parent = parentQuestion {
            regions.append(parent)
        }
        let sortedSubs = subquestions.sorted { a, b in
            let aTop = a.textBoundingBox.origin.y + a.textBoundingBox.height
            let bTop = b.textBoundingBox.origin.y + b.textBoundingBox.height
            return aTop > bTop
        }
        regions.append(contentsOf: sortedSubs)
        return regions
    }
}

extension DocumentQuestionRegions {
    /// Groups regions by top-level question, combining each parent with its subquestions.
    /// Returns groups sorted by page index ascending, then by Vision Y descending (top of page first).
    func groupedByTopLevelQuestion() -> [QuestionGroup] {
        var groups: [QuestionGroup] = []
        var usedSubquestionIDs = Set<UUID>()

        // Separate by type
        let questions = regions.filter { $0.regionType == .question }
        let subquestions = regions.filter { $0.regionType == .subquestion }

        for question in questions {
            let parentId = question.questionIdentifier ?? ""

            // Find subquestions whose identifier starts with parentId + "-"
            let matchingSubs = subquestions.filter { sub in
                guard let subId = sub.questionIdentifier else { return false }
                return subId.hasPrefix(parentId + "-")
            }
            matchingSubs.forEach { usedSubquestionIDs.insert($0.id) }

            // Compute union bounding box of all regions in this group
            let allRegions = [question] + matchingSubs
            let union = Self.computeUnionBoundingBox(for: allRegions)

            let groupId = "\(question.pageIndex)-\(parentId)"
            groups.append(QuestionGroup(
                id: groupId,
                parentQuestion: question,
                subquestions: matchingSubs,
                pageIndex: question.pageIndex,
                unionBoundingBox: union
            ))
        }

        // Handle orphaned subquestions (no matching parent)
        let orphanedSubs = subquestions.filter { !usedSubquestionIDs.contains($0.id) }
        for orphan in orphanedSubs {
            let orphanId = orphan.questionIdentifier ?? UUID().uuidString
            let union = Self.computeUnionBoundingBox(for: [orphan])

            groups.append(QuestionGroup(
                id: "\(orphan.pageIndex)-orphan-\(orphanId)",
                parentQuestion: nil,
                subquestions: [orphan],
                pageIndex: orphan.pageIndex,
                unionBoundingBox: union
            ))
        }

        // Sort by pageIndex ascending, then by Vision Y descending (top of page = higher Y in Vision coords)
        groups.sort { a, b in
            if a.pageIndex != b.pageIndex {
                return a.pageIndex < b.pageIndex
            }
            // Higher Vision Y means higher on the page (top-first)
            return a.unionBoundingBox.origin.y + a.unionBoundingBox.height
                > b.unionBoundingBox.origin.y + b.unionBoundingBox.height
        }

        return groups
    }

    /// Computes the union bounding box of all regions with 2% padding, clamped to 0–1
    private static func computeUnionBoundingBox(for regions: [QuestionRegion]) -> CGRect {
        guard let first = regions.first else { return .zero }

        var union = first.totalBoundingBox
        for region in regions.dropFirst() {
            union = union.union(region.totalBoundingBox)
        }

        // Add 2% padding on each side, clamped to 0–1
        let padding: CGFloat = 0.02
        let x = max(union.origin.x - padding, 0)
        let y = max(union.origin.y - padding, 0)
        let maxX = min(union.origin.x + union.width + padding, 1)
        let maxY = min(union.origin.y + union.height + padding, 1)

        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
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
