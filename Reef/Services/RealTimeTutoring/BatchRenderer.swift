//
//  BatchRenderer.swift
//  Reef
//
//  Renders stroke batches to JPEG images using PKDrawing's native rendering.
//  Recolors context strokes gray and new content strokes black.
//

import UIKit
import PencilKit

/// Renders batches of strokes to images for API submission.
enum BatchRenderer {

    // MARK: - Configuration

    /// Padding around the content bounding box (in canvas points)
    private static let padding: CGFloat = 50.0

    /// Scale factor for rendering (2x for Retina-quality output)
    private static let renderScale: CGFloat = 2.0

    /// JPEG compression quality (0.0–1.0)
    private static let jpegQuality: CGFloat = 0.8

    /// Maximum image dimension to avoid oversized payloads
    private static let maxDimension: CGFloat = 1024.0

    // MARK: - Rendering

    /// Render content strokes to JPEG data with optional context strokes in gray.
    /// - Parameters:
    ///   - contentStrokes: New strokes to render in black
    ///   - contextStrokes: Previous overlap strokes to render in gray
    /// - Returns: JPEG data and the content bounding rect, or nil if no strokes
    static func render(
        contentStrokes: [PKStroke],
        contextStrokes: [PKStroke] = []
    ) -> (imageData: Data, contentBounds: CGRect)? {
        guard !contentStrokes.isEmpty else { return nil }

        // Recolor context strokes to gray
        let grayContext = contextStrokes.map { stroke -> PKStroke in
            var recolored = stroke
            recolored.ink = PKInk(stroke.ink.inkType, color: .gray)
            return recolored
        }

        // Recolor content strokes to black
        let blackContent = contentStrokes.map { stroke -> PKStroke in
            var recolored = stroke
            recolored.ink = PKInk(stroke.ink.inkType, color: .black)
            return recolored
        }

        // Combine all strokes
        let allStrokes = grayContext + blackContent
        let drawing = PKDrawing(strokes: allStrokes)

        // Compute bounding box of all strokes with padding
        let allPoints = allStrokes.flatMap { stroke -> [CGPoint] in
            StrokePointExtractor.extractOnCurvePoints(from: stroke)
        }
        guard !allPoints.isEmpty else { return nil }

        let rawBounds = GeometryUtils.boundingRect(of: allPoints)
        let paddedBounds = rawBounds.insetBy(dx: -padding, dy: -padding)

        // Clamp to non-negative origin
        let renderRect = CGRect(
            x: max(paddedBounds.origin.x, 0),
            y: max(paddedBounds.origin.y, 0),
            width: paddedBounds.width,
            height: paddedBounds.height
        )

        guard renderRect.width > 0 && renderRect.height > 0 else { return nil }

        // Compute scale to keep within max dimension
        let scaleFactor: CGFloat
        let maxSide = max(renderRect.width, renderRect.height)
        if maxSide * renderScale > maxDimension {
            scaleFactor = maxDimension / maxSide
        } else {
            scaleFactor = renderScale
        }

        // Render using PKDrawing's native renderer with light-mode trait
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        var image: UIImage!
        lightTraits.performAsCurrent {
            image = drawing.image(from: renderRect, scale: scaleFactor)
        }

        guard let jpegData = image.jpegData(compressionQuality: jpegQuality) else { return nil }

        return (imageData: jpegData, contentBounds: rawBounds)
    }
}
