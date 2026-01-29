//
//  PKStrokeGenerator.swift
//  Reef
//
//  Builds replacement PKStrokes for snapped shapes (lines, rectangles,
//  triangles, circles), preserving the original ink properties.
//

import Foundation
import CoreGraphics
import PencilKit

// MARK: - StrokeGenerator

/// Generates replacement `PKStroke` objects for detected shapes.
enum StrokeGenerator {

    /// Number of evenly-spaced points along a line.
    private static let linePointCount = 24

    /// Number of points per edge for polygons (rectangles, triangles).
    private static let polygonPointsPerEdge = 16

    /// Number of segments for a circle (produces segments+1 points, closing back to start).
    private static let circleSegments = 72

    /// Generate a circle `PKStroke` from center and radius.
    static func generateCircle(center: CGPoint, radius: CGFloat, originalStroke: PKStroke) -> PKStroke {
        let properties = extractInkProperties(from: originalStroke)

        var strokePoints: [PKStrokePoint] = []
        strokePoints.reserveCapacity(circleSegments + 1)

        for i in 0...circleSegments {
            let angle = CGFloat(i) / CGFloat(circleSegments) * 2.0 * .pi
            let location = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            strokePoints.append(makePoint(location: location, index: i, properties: properties))
        }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    /// Generate a straight-line `PKStroke` from start to end.
    static func generateLine(from start: CGPoint, to end: CGPoint, originalStroke: PKStroke) -> PKStroke {
        let properties = extractInkProperties(from: originalStroke)

        var strokePoints: [PKStrokePoint] = []
        strokePoints.reserveCapacity(linePointCount + 1)

        for i in 0...linePointCount {
            let t = CGFloat(i) / CGFloat(linePointCount)
            let location = CGPoint(
                x: start.x + t * (end.x - start.x),
                y: start.y + t * (end.y - start.y)
            )
            strokePoints.append(makePoint(location: location, index: i, properties: properties))
        }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    /// Generate a rectangle `PKStroke` from 4 ordered corners.
    static func generateRectangle(corners: [CGPoint], originalStroke: PKStroke) -> PKStroke {
        generatePolygon(corners: corners, originalStroke: originalStroke)
    }

    /// Generate a triangle `PKStroke` from 3 corners.
    static func generateTriangle(corners: [CGPoint], originalStroke: PKStroke) -> PKStroke {
        generatePolygon(corners: corners, originalStroke: originalStroke)
    }

    /// Generate a closed polygon `PKStroke` from ordered corners.
    private static func generatePolygon(corners: [CGPoint], originalStroke: PKStroke) -> PKStroke {
        let properties = extractInkProperties(from: originalStroke)
        let edgeCount = corners.count

        var strokePoints: [PKStrokePoint] = []
        strokePoints.reserveCapacity(edgeCount * polygonPointsPerEdge + 1)

        var index = 0
        for edgeIndex in 0..<edgeCount {
            let start = corners[edgeIndex]
            let end = corners[(edgeIndex + 1) % edgeCount]
            for step in 0..<polygonPointsPerEdge {
                let t = CGFloat(step) / CGFloat(polygonPointsPerEdge)
                let location = CGPoint(
                    x: start.x + t * (end.x - start.x),
                    y: start.y + t * (end.y - start.y)
                )
                strokePoints.append(makePoint(location: location, index: index, properties: properties))
                index += 1
            }
        }

        // Closing point back to first corner
        strokePoints.append(makePoint(location: corners[0], index: index, properties: properties))

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: originalStroke.ink, path: path)
    }

    // MARK: - Private

    private struct InkProperties {
        let averageForce: CGFloat
        let averageSize: CGSize
        let averageOpacity: CGFloat
        let averageAzimuth: CGFloat
        let averageAltitude: CGFloat
    }

    private static func makePoint(location: CGPoint, index: Int, properties: InkProperties) -> PKStrokePoint {
        PKStrokePoint(
            location: location,
            timeOffset: TimeInterval(index) * 0.01,
            size: properties.averageSize,
            opacity: properties.averageOpacity,
            force: properties.averageForce,
            azimuth: properties.averageAzimuth,
            altitude: properties.averageAltitude
        )
    }

    private static func extractInkProperties(from stroke: PKStroke) -> InkProperties {
        let points = stroke.path
        let count = points.count

        guard count > 0 else {
            return InkProperties(
                averageForce: 0.5,
                averageSize: CGSize(width: 3.0, height: 3.0),
                averageOpacity: 1.0,
                averageAzimuth: 0.0,
                averageAltitude: .pi / 2
            )
        }

        var totalForce: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalOpacity: CGFloat = 0
        var totalAzimuth: CGFloat = 0
        var totalAltitude: CGFloat = 0

        for i in 0..<count {
            let point = points[i]
            totalForce += point.force
            totalWidth += point.size.width
            totalHeight += point.size.height
            totalOpacity += point.opacity
            totalAzimuth += point.azimuth
            totalAltitude += point.altitude
        }

        let n = CGFloat(count)
        return InkProperties(
            averageForce: totalForce / n,
            averageSize: CGSize(width: totalWidth / n, height: totalHeight / n),
            averageOpacity: totalOpacity / n,
            averageAzimuth: totalAzimuth / n,
            averageAltitude: totalAltitude / n
        )
    }
}
