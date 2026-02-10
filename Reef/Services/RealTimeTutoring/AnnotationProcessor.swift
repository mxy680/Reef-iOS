//
//  AnnotationProcessor.swift
//  Reef
//
//  Processes annotation strokes and maintains running annotation state.
//  Stub implementation for Phase 1 — full cross-referencing with
//  transcription comes in Phase 3.
//

import Foundation
import CoreGraphics

/// Processes annotation-classified strokes and accumulates annotation state.
enum AnnotationProcessor {

    // MARK: - State

    /// Running annotation state for the current problem/session.
    struct AnnotationState {
        /// Bounding boxes of boxed regions (from box strokes)
        var boxedRegions: [CGRect] = []

        /// Bounding boxes of circled regions (from circle strokes)
        var circledRegions: [CGRect] = []

        /// Underline positions (y-position and x-range)
        var underlines: [Underline] = []

        /// Regions that have been scratched out
        var scratchedOutRegions: [CGRect] = []

        /// Arrow connectors (start → end)
        var arrows: [Arrow] = []

        struct Underline {
            let minX: CGFloat
            let maxX: CGFloat
            let y: CGFloat
        }

        struct Arrow {
            let start: CGPoint
            let end: CGPoint
        }
    }

    // MARK: - Processing

    /// Process a batch of annotation strokes and update the annotation state.
    /// - Parameters:
    ///   - annotations: Annotation-classified stroke metadata from the current batch
    ///   - state: The running annotation state to update
    static func process(annotations: [StrokeMetadata], state: inout AnnotationState) {
        for meta in annotations {
            switch meta.label {
            case .box:
                state.boxedRegions.append(meta.features.boundingBox)

            case .circle:
                state.circledRegions.append(meta.features.boundingBox)

            case .underline:
                let bb = meta.features.boundingBox
                state.underlines.append(AnnotationState.Underline(
                    minX: bb.minX,
                    maxX: bb.maxX,
                    y: bb.midY
                ))

            case .scratchOut:
                state.scratchedOutRegions.append(meta.features.boundingBox)

            case .arrow:
                state.arrows.append(AnnotationState.Arrow(
                    start: meta.startPoint,
                    end: meta.endPoint
                ))

            case .content, .unknown:
                break
            }
        }
    }
}
