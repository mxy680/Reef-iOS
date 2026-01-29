//
//  ShapeDetector.swift
//  Reef
//
//  Orchestrator for diagram autosnap. Supports lines, rectangles, triangles, and circles.
//

import PencilKit

/// Single entry point for autosnap detection.
///
/// Call `detect(stroke:)` with a completed `PKStroke`. Returns a replacement
/// `PKStroke` if the stroke matches a recognized shape, otherwise `nil`.
enum ShapeDetector {

    /// Detect and replace a freehand stroke with a snapped shape.
    ///
    /// 1. Line — open strokes (start/end far apart)
    /// 2. Closed shapes — circle vs rectangle scored together, best wins
    static func detect(stroke: PKStroke) -> PKStroke? {
        // Try line detection (open strokes)
        if let line = LineClassifier.detectLine(stroke: stroke) {
            return StrokeGenerator.generateLine(
                from: line.start,
                to: line.end,
                originalStroke: stroke
            )
        }

        // Try closed shape detection (triangle, rectangle, or circle)
        if let shape = ClosedShapeClassifier.classify(stroke: stroke) {
            switch shape {
            case .circle(let center, let radius):
                return StrokeGenerator.generateCircle(
                    center: center,
                    radius: radius,
                    originalStroke: stroke
                )
            case .rectangle(let corners):
                return StrokeGenerator.generateRectangle(
                    corners: corners,
                    originalStroke: stroke
                )
            case .triangle(let corners):
                return StrokeGenerator.generateTriangle(
                    corners: corners,
                    originalStroke: stroke
                )
            }
        }

        return nil
    }
}
