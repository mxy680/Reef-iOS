//
//  StrokeClassifier.swift
//  Reef
//
//  Feature extraction and heuristic rule-based classification for strokes.
//  Reuses StrokePointExtractor, GeometryUtils, and VelocityCalculator.
//

import Foundation
import CoreGraphics
import PencilKit

/// Classifies strokes as content or annotation types using geometric/velocity features.
enum StrokeClassifier {

    // MARK: - Feature Extraction

    /// Extract geometric and velocity features from a PKStroke.
    static func extractFeatures(from stroke: PKStroke) -> StrokeFeatures {
        let points = StrokePointExtractor.extractOnCurvePoints(from: stroke)
        let pkPoints = stroke.path.map { $0 }

        // Bounding box
        let boundingBox = GeometryUtils.boundingRect(of: points)
        let width = max(boundingBox.width, 1)
        let height = max(boundingBox.height, 1)
        let aspectRatio = width / height

        // Closure ratio
        let pathLength = Self.computePathLength(points)
        let closureRatio: CGFloat
        if pathLength > 0, let first = points.first, let last = points.last {
            let gap = hypot(last.x - first.x, last.y - first.y)
            closureRatio = 1.0 - min(gap / pathLength, 1.0)
        } else {
            closureRatio = 0
        }

        // Curvature variance
        let curvatureVariance = Self.computeCurvatureVariance(points)

        // Direction reversals
        let directionReversals = Self.countDirectionReversals(points)

        // Velocity features
        let velocities = VelocityCalculator.calculateVelocity(from: pkPoints)
        let averageVelocity = VelocityCalculator.averageVelocity(from: pkPoints)
        let velocityVariance: Double
        if !velocities.isEmpty {
            let mean = velocities.reduce(0, +) / Double(velocities.count)
            let sumSquaredDiffs = velocities.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
            velocityVariance = sqrt(sumSquaredDiffs / Double(velocities.count))
        } else {
            velocityVariance = 0
        }

        // Point density
        let area = width * height
        let pointDensity = CGFloat(points.count) / max(area, 1)

        // Duration
        let duration: TimeInterval
        if pkPoints.count >= 2 {
            duration = pkPoints.last!.timeOffset - pkPoints.first!.timeOffset
        } else {
            duration = 0
        }

        // Corner count via RDP
        let diagonal = hypot(width, height)
        let epsilon = diagonal * 0.04
        let simplified = GeometryUtils.rdpSimplify(points, epsilon: epsilon)
        let cornerCount = simplified.count

        return StrokeFeatures(
            boundingBox: boundingBox,
            aspectRatio: aspectRatio,
            closureRatio: closureRatio,
            curvatureVariance: curvatureVariance,
            directionReversals: directionReversals,
            averageVelocity: averageVelocity,
            velocityVariance: velocityVariance,
            pointDensity: pointDensity,
            duration: duration,
            pathLength: pathLength,
            cornerCount: cornerCount
        )
    }

    // MARK: - Classification

    /// Classify a stroke based on its features and the active tool.
    /// Returns both the label and the computed features to avoid double extraction.
    /// - Parameters:
    ///   - stroke: The PKStroke to classify
    ///   - activeTool: The currently selected canvas tool
    /// - Returns: A tuple of (label, features) for this stroke
    static func classify(stroke: PKStroke, activeTool: CanvasTool) -> (label: StrokeLabel, features: StrokeFeatures) {
        let features = extractFeatures(from: stroke)

        // Toolbar override: diagram and highlighter bypass classification
        switch activeTool {
        case .diagram, .highlighter:
            return (.unknown, features)
        case .eraser, .lasso, .textBox, .pan:
            return (.unknown, features)
        case .pen:
            break
        }

        // TODO: Re-enable heuristic classification after threshold tuning (Step 8)
        // let label = classifyFromFeatures(features)
        return (.content, features)
    }

    /// Apply heuristic rules to classify a stroke from its features.
    static func classifyFromFeatures(_ f: StrokeFeatures) -> StrokeLabel {
        // Scratch-out: rapid back-and-forth motion
        if f.directionReversals > 10 && f.pointDensity > 0.01 && f.duration < 1.5 {
            return .scratchOut
        }

        // Closed shapes (box or circle)
        if f.closureRatio > 0.85 {
            // Circle: roughly uniform curvature, roughly square bounding box
            if f.aspectRatio > 0.6 && f.aspectRatio < 1.6 && f.curvatureVariance < 0.4 && f.cornerCount >= 8 {
                return .circle
            }

            // Box: ~4 direction changes, rectangular aspect
            if f.aspectRatio > 0.3 && f.aspectRatio < 3.0 && f.cornerCount <= 6 && f.curvatureVariance < 0.6 {
                return .box
            }
        }

        // Underline: very wide and flat, minimal curvature
        if f.aspectRatio > 4.0 && f.curvatureVariance < 0.3 && f.directionReversals <= 2 {
            return .underline
        }

        // Arrow: open stroke with fork at end
        // Full arrow detection will be added in tuning phase (Step 8)

        return .content
    }

    // MARK: - Geometry Helpers

    /// Compute total path length from point-to-point distances.
    private static func computePathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var length: CGFloat = 0
        for i in 1..<points.count {
            length += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }
        return length
    }

    /// Compute variance of curvature (angle changes between consecutive triplets).
    private static func computeCurvatureVariance(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }

        var angles: [CGFloat] = []
        angles.reserveCapacity(points.count - 2)

        for i in 1..<(points.count - 1) {
            let prev = points[i - 1]
            let curr = points[i]
            let next = points[i + 1]

            let dx1 = curr.x - prev.x
            let dy1 = curr.y - prev.y
            let dx2 = next.x - curr.x
            let dy2 = next.y - curr.y

            let angle = atan2(dx1 * dy2 - dy1 * dx2, dx1 * dx2 + dy1 * dy2)
            angles.append(angle)
        }

        guard !angles.isEmpty else { return 0 }

        let mean = angles.reduce(0, +) / CGFloat(angles.count)
        let variance = angles.reduce(CGFloat(0)) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(angles.count)
        return sqrt(variance)
    }

    /// Count direction reversals in horizontal and vertical axes.
    private static func countDirectionReversals(_ points: [CGPoint]) -> Int {
        guard points.count >= 3 else { return 0 }

        var reversals = 0
        var prevDx: CGFloat = 0
        var prevDy: CGFloat = 0

        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y

            // Check horizontal reversal
            if prevDx != 0 && dx != 0 && (prevDx > 0) != (dx > 0) {
                reversals += 1
            }
            // Check vertical reversal
            if prevDy != 0 && dy != 0 && (prevDy > 0) != (dy > 0) {
                reversals += 1
            }

            if dx != 0 { prevDx = dx }
            if dy != 0 { prevDy = dy }
        }

        return reversals
    }
}
