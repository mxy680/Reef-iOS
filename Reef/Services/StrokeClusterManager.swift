//
//  StrokeClusterManager.swift
//  Reef
//
//  Thin data holder for server-side stroke clustering.
//  Tracks known stroke bounds, serializes them for the WebSocket,
//  and applies cluster responses from the server.
//

import Foundation
import PencilKit

// MARK: - StrokeBoundsKey

/// Hashable wrapper around CGRect for stroke identity.
/// PKStroke has no public stable ID, so we use `renderBounds` as a
/// deterministic proxy — two readings of the same unchanged stroke
/// produce identical bounds.
struct StrokeBoundsKey: Hashable {
    let origin: CGPoint
    let size: CGSize

    init(_ rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }

    var rect: CGRect {
        CGRect(origin: origin, size: size)
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    static func == (lhs: StrokeBoundsKey, rhs: StrokeBoundsKey) -> Bool {
        lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}

// MARK: - StrokeCluster

/// A spatial cluster of strokes, as reported by the server.
struct StrokeCluster {
    let id: String
    let boundingBox: CGRect
    let strokeCount: Int
    let isDirty: Bool
}

// MARK: - StrokeClusterManager

/// Manages stroke data for a single canvas page.
///
/// Tracks known stroke bounds so the coordinator can detect changes,
/// serializes bounds for the WebSocket, and applies server-returned clusters.
final class StrokeClusterManager {

    private(set) var clusters: [StrokeCluster] = []

    /// All stroke keys the manager currently knows about.
    private(set) var knownKeys: Set<StrokeBoundsKey> = []

    // MARK: - Public API

    /// Updates the known stroke set. Returns `true` if anything changed.
    @discardableResult
    func update(with strokes: [PKStroke]) -> Bool {
        let currentKeys = Set(strokes.map { StrokeBoundsKey($0.renderBounds) })
        let changed = currentKeys != knownKeys
        knownKeys = currentKeys
        return changed
    }

    /// Serializes all known stroke bounds for the WebSocket message.
    func strokeBoundsPayload() -> [[String: CGFloat]] {
        knownKeys.map { key in
            [
                "x": key.rect.origin.x,
                "y": key.rect.origin.y,
                "w": key.rect.size.width,
                "h": key.rect.size.height
            ]
        }
    }

    /// Applies cluster data returned by the server, rebuilding `clusters`.
    func applyClusters(_ serverClusters: [[String: Any]]) {
        clusters = serverClusters.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let bboxDict = dict["bbox"] as? [String: Double],
                  let x = bboxDict["x"],
                  let y = bboxDict["y"],
                  let w = bboxDict["w"],
                  let h = bboxDict["h"],
                  let strokeCount = dict["stroke_count"] as? Int,
                  let dirty = dict["dirty"] as? Bool
            else { return nil }

            return StrokeCluster(
                id: id,
                boundingBox: CGRect(x: x, y: y, width: w, height: h),
                strokeCount: strokeCount,
                isDirty: dirty
            )
        }
    }

    /// Returns only the clusters flagged as dirty by the server.
    var dirtyClusters: [StrokeCluster] {
        clusters.filter { $0.isDirty }
    }
}
