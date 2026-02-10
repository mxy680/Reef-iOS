//
//  StrokeFeatures.swift
//  Reef
//
//  Computed geometric and velocity features for a single stroke.
//

import Foundation
import CoreGraphics

/// Geometric and velocity features extracted from a PKStroke for classification.
struct StrokeFeatures {
    /// Bounding box of the stroke
    let boundingBox: CGRect

    /// Width / height of bounding box (clamped > 0)
    let aspectRatio: CGFloat

    /// Distance from first to last point / total path length (0 = open, 1 = closed)
    let closureRatio: CGFloat

    /// Standard deviation of angle changes between consecutive point triplets
    let curvatureVariance: CGFloat

    /// Number of times the stroke reverses horizontal or vertical direction
    let directionReversals: Int

    /// Average velocity in points per second
    let averageVelocity: Double

    /// Standard deviation of instantaneous velocity
    let velocityVariance: Double

    /// Points per unit bounding box area
    let pointDensity: CGFloat

    /// Total duration of the stroke in seconds
    let duration: TimeInterval

    /// Total path length (sum of point-to-point distances)
    let pathLength: CGFloat

    /// Number of corners detected via RDP simplification
    let cornerCount: Int
}
