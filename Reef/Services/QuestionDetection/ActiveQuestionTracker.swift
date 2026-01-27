//
//  ActiveQuestionTracker.swift
//  Reef
//
//  Tracks which question the user is currently working on based on stroke position
//

import Foundation
import PencilKit
import Combine

/// Tracks the currently active question based on user drawing position
class ActiveQuestionTracker: ObservableObject {
    /// The currently active question region
    @Published private(set) var activeQuestion: QuestionRegion?

    /// Configured question regions for the document
    private var questionRegions: DocumentQuestionRegions?

    /// Document size in points (for coordinate conversion)
    private var documentSize: CGSize = .zero

    /// Current page being viewed
    private var currentPageIndex: Int = 0

    // MARK: - Configuration

    /// Configure the tracker with question regions and document size
    /// - Parameters:
    ///   - regions: Detected question regions for the document
    ///   - documentSize: Size of the document in points
    func configure(with regions: DocumentQuestionRegions?, documentSize: CGSize) {
        self.questionRegions = regions
        self.documentSize = documentSize
        self.activeQuestion = nil
    }

    /// Set the current page index
    /// - Parameter pageIndex: The page currently being viewed
    func setCurrentPage(_ pageIndex: Int) {
        self.currentPageIndex = pageIndex

        // Clear active question if it's on a different page
        if let active = activeQuestion, active.pageIndex != pageIndex {
            activeQuestion = nil
        }
    }

    // MARK: - Stroke Tracking

    /// Update the active question based on a completed stroke
    /// - Parameter stroke: The completed PKStroke
    func updateFromStroke(_ stroke: PKStroke) {
        guard let regions = questionRegions else { return }
        guard documentSize.width > 0 && documentSize.height > 0 else { return }

        // Get the stroke's bounding box
        let strokeBounds = stroke.renderBounds

        // Convert stroke center to normalized Vision coordinates
        let centerX = strokeBounds.midX
        let centerY = strokeBounds.midY

        let normalizedPoint = convertToVisionCoordinates(
            point: CGPoint(x: centerX, y: centerY)
        )

        // Find the region containing this point
        if let region = regions.region(containing: normalizedPoint, onPage: currentPageIndex) {
            activeQuestion = region
        }
    }

    /// Update active question based on raw canvas coordinates
    /// - Parameter point: Point in canvas coordinates (top-left origin)
    func updateFromPoint(_ point: CGPoint) {
        guard let regions = questionRegions else { return }
        guard documentSize.width > 0 && documentSize.height > 0 else { return }

        let normalizedPoint = convertToVisionCoordinates(point: point)

        if let region = regions.region(containing: normalizedPoint, onPage: currentPageIndex) {
            activeQuestion = region
        }
    }

    // MARK: - Context Generation

    /// Get the active question context for AI feedback
    /// - Returns: Context about the active question, if any
    func getActiveQuestionContext() -> ActiveQuestionContext? {
        guard let question = activeQuestion else { return nil }
        return ActiveQuestionContext(from: question)
    }

    // MARK: - Coordinate Conversion

    /// Convert canvas coordinates (top-left origin, points) to Vision coordinates (bottom-left origin, normalized 0-1)
    /// - Parameter point: Point in canvas coordinates
    /// - Returns: Normalized point in Vision coordinate system
    private func convertToVisionCoordinates(point: CGPoint) -> CGPoint {
        // Canvas: top-left origin, Y increases downward
        // Vision: bottom-left origin, Y increases upward, normalized 0-1

        let normalizedX = point.x / documentSize.width
        let normalizedY = 1.0 - (point.y / documentSize.height)

        return CGPoint(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY))
        )
    }

    /// Convert Vision coordinates (bottom-left origin, normalized) to canvas coordinates (top-left origin, points)
    /// - Parameter normalizedPoint: Normalized point in Vision coordinate system
    /// - Returns: Point in canvas coordinates
    func convertToCanvasCoordinates(normalizedPoint: CGPoint) -> CGPoint {
        let canvasX = normalizedPoint.x * documentSize.width
        let canvasY = (1.0 - normalizedPoint.y) * documentSize.height

        return CGPoint(x: canvasX, y: canvasY)
    }

    /// Convert a Vision bounding box to canvas coordinates
    /// - Parameter rect: Normalized rect in Vision coordinates
    /// - Returns: Rect in canvas coordinates
    func convertToCanvasRect(_ rect: CGRect) -> CGRect {
        let origin = convertToCanvasCoordinates(
            normalizedPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        let size = CGSize(
            width: rect.width * documentSize.width,
            height: rect.height * documentSize.height
        )
        return CGRect(origin: origin, size: size)
    }
}
