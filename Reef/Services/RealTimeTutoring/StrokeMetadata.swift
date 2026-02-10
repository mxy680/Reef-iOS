//
//  StrokeMetadata.swift
//  Reef
//
//  Per-stroke buffer entry for the real-time tutoring pipeline.
//

import Foundation
import CoreGraphics
import PencilKit

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
}
