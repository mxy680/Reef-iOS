//
//  StrokeMetadata.swift
//  Reef
//
//  Per-stroke buffer entry for the real-time tutoring pipeline.
//

import Foundation
import CoreGraphics
import PencilKit

/// Lightweight fingerprint for matching PKStrokes across snapshots (e.g. erasure detection).
struct StrokeFingerprint: Equatable {
    let pointCount: Int
    let bounds: CGRect

    init(stroke: PKStroke) {
        self.pointCount = stroke.path.count
        self.bounds = stroke.renderBounds
    }

    static func == (lhs: StrokeFingerprint, rhs: StrokeFingerprint) -> Bool {
        lhs.pointCount == rhs.pointCount && lhs.bounds == rhs.bounds
    }
}

/// Metadata for a single buffered stroke in the pending batch.
struct StrokeMetadata {
    /// Reference to the original PencilKit stroke
    let stroke: PKStroke

    /// When the stroke was completed
    let timestamp: Date

    /// Which page container the stroke was on (0-indexed)
    let pageIndex: Int?

    /// Classification label
    let label: StrokeLabel

    /// Computed features used for classification
    let features: StrokeFeatures

    /// First point of the stroke in canvas coordinates
    let startPoint: CGPoint

    /// Last point of the stroke in canvas coordinates
    let endPoint: CGPoint

    /// Fingerprint for matching this stroke against canvas strokes during erasure detection
    let fingerprint: StrokeFingerprint
}
