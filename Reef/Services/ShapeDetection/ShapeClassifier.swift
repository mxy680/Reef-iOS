//
//  ShapeClassifier.swift
//  Reef
//
//  Stroke classification for diagram autosnap.
//  Detects lines, circles, and rectangles from freehand PKStrokes.
//

import Foundation
import CoreGraphics
import PencilKit

// MARK: - Shared Utilities

/// Shared point-extraction from PKStroke B-spline paths.
enum StrokePointExtractor {

    /// Extract on-curve points from a PKStroke by interpolating the B-spline path.
    static func extractOnCurvePoints(from stroke: PKStroke) -> [CGPoint] {
        let path = stroke.path
        guard path.count >= 2 else {
            return path.map { $0.location }
        }
        let start = CGFloat(path.startIndex)
        let end = CGFloat(path.endIndex - 1)
        let slice = path.interpolatedPoints(
            in: start...end,
            by: .distance(3.0)
        )
        let points = slice.map { $0.location }
        if points.isEmpty {
            return path.map { $0.location }
        }
        return points
    }
}

// MARK: - LineClassifier

/// Detects if a stroke is a roughly straight line.
enum LineClassifier {

    private static let minimumPointCount = 5
    private static let straightnessThreshold: CGFloat = 0.12
    private static let minimumLineLength: CGFloat = 30.0

    static func detectLine(stroke: PKStroke) -> (start: CGPoint, end: CGPoint)? {
        let points = StrokePointExtractor.extractOnCurvePoints(from: stroke)
        guard points.count >= minimumPointCount else { return nil }

        let start = points.first!
        let end = points.last!
        let lineLength = hypot(end.x - start.x, end.y - start.y)

        guard lineLength >= minimumLineLength else { return nil }

        var maxDist: CGFloat = 0
        for point in points {
            let dist = GeometryUtils.perpendicularDistance(point: point, lineStart: start, lineEnd: end)
            maxDist = max(maxDist, dist)
        }

        guard maxDist / lineLength <= straightnessThreshold else { return nil }

        return (start: start, end: end)
    }
}

// MARK: - Closed Shape Classification

/// Result of closed-shape classification.
enum ClosedShapeResult {
    case circle(center: CGPoint, radius: CGFloat)
    case rectangle(corners: [CGPoint])
    case triangle(corners: [CGPoint])
}

/// Unified classifier for closed shapes.
///
/// Uses RDP corner counting as the primary discriminator:
/// - Few corners (≤ 6) → rectangle candidate
/// - Many vertices (≥ 8) → circle candidate
///
/// Then validates with shape-specific checks (box fill for rectangles,
/// radius CV for circles).
enum ClosedShapeClassifier {

    private static let minimumPointCount = 10
    private static let closureThreshold: CGFloat = 0.45
    private static let minimumSize: CGFloat = 30.0

    /// RDP epsilon as fraction of bounding diagonal.
    private static let rdpEpsilonFraction: CGFloat = 0.04

    /// Max RDP vertices to consider a rectangle (4 corners + edge noise).
    private static let maxRectangleVertices = 6

    /// Min RDP vertices to consider a circle (no sharp corners).
    private static let minCircleVertices = 8

    /// Rectangle: polygon area / bounding box area.
    /// Rectangles fill ~100% of bbox, triangles fill ~50%.
    private static let rectMinBoxFill: CGFloat = 0.78

    /// Triangle: polygon area / bounding box area.
    /// Triangles fill 30–60% of bbox. Upper bound separates from rectangles.
    private static let triangleMaxBoxFill: CGFloat = 0.70

    /// Triangle: minimum polygon area / bounding box area to reject slivers.
    private static let triangleMinBoxFill: CGFloat = 0.25

    /// Circle: max coefficient of variation of distances from centroid.
    private static let circleMaxRadiusCV: CGFloat = 0.25

    /// Circle: bounding box must be roughly square.
    private static let circleMaxAspectRatio: CGFloat = 1.5

    static func classify(stroke: PKStroke) -> ClosedShapeResult? {
        let points = StrokePointExtractor.extractOnCurvePoints(from: stroke)
        guard points.count >= minimumPointCount else { return nil }

        let bounds = GeometryUtils.boundingRect(of: points)
        let diagonal = hypot(bounds.width, bounds.height)
        guard diagonal > 0 else { return nil }
        guard max(bounds.width, bounds.height) >= minimumSize else { return nil }

        // Must be approximately closed
        let gap = hypot(
            points.last!.x - points.first!.x,
            points.last!.y - points.first!.y
        )
        guard gap / diagonal <= closureThreshold else { return nil }

        // Count corners via RDP simplification
        let epsilon = diagonal * rdpEpsilonFraction
        let simplified = GeometryUtils.rdpSimplify(points, epsilon: epsilon)
        let vertexCount = simplified.count

        // Few corners → polygon candidate (triangle or rectangle)
        if vertexCount <= maxRectangleVertices {
            let polyArea = abs(GeometryUtils.shoelaceArea(of: points))
            let boxArea = bounds.width * bounds.height
            guard boxArea > 0 else { return nil }
            let boxFill = polyArea / boxArea

            // High box fill → rectangle
            if boxFill >= rectMinBoxFill
                && bounds.width >= minimumSize
                && bounds.height >= minimumSize {
                return .rectangle(corners: [
                    CGPoint(x: bounds.minX, y: bounds.minY),
                    CGPoint(x: bounds.maxX, y: bounds.minY),
                    CGPoint(x: bounds.maxX, y: bounds.maxY),
                    CGPoint(x: bounds.minX, y: bounds.maxY)
                ])
            }

            // Low box fill → triangle
            if boxFill >= triangleMinBoxFill && boxFill <= triangleMaxBoxFill {
                if let corners = extractTriangleCorners(from: points, simplified: simplified) {
                    return .triangle(corners: corners)
                }
            }
        }

        // Many vertices (no corners) → circle candidate
        if vertexCount >= minCircleVertices {
            let aspect = max(bounds.width, bounds.height) / max(min(bounds.width, bounds.height), 1)
            guard aspect <= circleMaxAspectRatio else { return nil }

            let cx = points.reduce(CGFloat(0)) { $0 + $1.x } / CGFloat(points.count)
            let cy = points.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(points.count)
            let radii = points.map { hypot($0.x - cx, $0.y - cy) }
            let meanRadius = radii.reduce(CGFloat(0), +) / CGFloat(radii.count)
            guard meanRadius > 0 else { return nil }

            let variance = radii.reduce(CGFloat(0)) { $0 + ($1 - meanRadius) * ($1 - meanRadius) } / CGFloat(radii.count)
            let cv = sqrt(variance) / meanRadius
            guard cv <= circleMaxRadiusCV else { return nil }

            return .circle(center: CGPoint(x: cx, y: cy), radius: meanRadius)
        }

        return nil
    }

    // MARK: - Triangle Corner Extraction

    /// Extract 3 corners from the stroke points.
    /// Finds the two farthest-apart points, then the third point with max
    /// perpendicular distance from the line between them.
    private static func extractTriangleCorners(from points: [CGPoint], simplified: [CGPoint]) -> [CGPoint]? {
        // Use simplified points to find corners
        let candidates = simplified
        guard candidates.count >= 3 else { return nil }

        // Find the two points with maximum distance
        var maxDist: CGFloat = 0
        var a = 0, b = 1
        for i in 0..<candidates.count {
            for j in (i + 1)..<candidates.count {
                let d = hypot(candidates[j].x - candidates[i].x, candidates[j].y - candidates[i].y)
                if d > maxDist {
                    maxDist = d
                    a = i
                    b = j
                }
            }
        }

        // Find the third point with max perpendicular distance from line a→b
        var maxPerp: CGFloat = 0
        var c = -1
        for i in 0..<candidates.count where i != a && i != b {
            let d = GeometryUtils.perpendicularDistance(
                point: candidates[i],
                lineStart: candidates[a],
                lineEnd: candidates[b]
            )
            if d > maxPerp {
                maxPerp = d
                c = i
            }
        }

        guard c >= 0 else { return nil }

        // Ensure the triangle isn't too flat (min perpendicular height relative to base)
        guard maxPerp / maxDist >= 0.15 else { return nil }

        return [candidates[a], candidates[b], candidates[c]]
    }
}

// MARK: - Geometry Utilities

/// Pure geometry helpers shared across classifiers.
enum GeometryUtils {

    static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        let cross = abs(dy * (point.x - lineStart.x) - dx * (point.y - lineStart.y))
        return cross / sqrt(lengthSq)
    }

    static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func rdpSimplify(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var maxDist: CGFloat = 0
        var maxIndex = 0
        let lineStart = points.first!
        let lineEnd = points.last!

        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: lineStart, lineEnd: lineEnd)
            if dist > maxDist {
                maxDist = dist
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = rdpSimplify(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = rdpSimplify(Array(points[maxIndex...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [lineStart, lineEnd]
        }
    }

    /// Signed area of a polygon using the shoelace formula.
    static func shoelaceArea(of points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        let n = points.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        return area / 2.0
    }
}
