//
//  StrokeLabel.swift
//  Reef
//
//  Classification labels for strokes in the real-time tutoring pipeline.
//

import Foundation

/// Classification label assigned to each stroke by StrokeClassifier.
enum StrokeLabel: String, CaseIterable {
    case content
    case box
    case circle
    case underline
    case scratchOut
    case arrow
    case unknown

    /// Whether this label represents an annotation (non-content) stroke.
    var isAnnotation: Bool {
        self != .content && self != .unknown
    }
}
