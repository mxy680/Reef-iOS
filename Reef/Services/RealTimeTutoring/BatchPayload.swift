//
//  BatchPayload.swift
//  Reef
//
//  Output payload from the stroke batching pipeline, ready for API submission.
//

import Foundation
import CoreGraphics

/// A rendered batch of strokes ready for server-side transcription.
struct BatchPayload {
    /// Sequential batch index (monotonically increasing per session)
    let batchIndex: Int

    /// JPEG image data of rendered strokes (nil if no content strokes)
    let imageData: Data?

    /// Bounding box of rendered content in canvas coordinates
    let contentBounds: CGRect

    /// Number of content strokes in this batch
    let strokeCount: Int

    /// Number of annotation strokes in this batch
    let annotationCount: Int

    /// Whether erased strokes are present (tells server to expect corrected_transcript)
    let hasErasures: Bool

    /// Metadata for all strokes in this batch
    let strokeMetadata: [StrokeMetadata]

    /// Page index where the majority of strokes were drawn
    let primaryPageIndex: Int?

    /// When this batch was created
    let timestamp: Date

    /// Question number (1-based) if in assignment mode, nil in document mode
    let questionNumber: Int?

    /// Resolved subquestion label (e.g. "a", "b"), nil if not in assignment mode or no region data
    let subquestionLabel: String?
}
