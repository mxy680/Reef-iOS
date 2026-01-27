//
//  VelocityCalculator.swift
//  Reef
//
//  Utility for calculating velocity from PKStrokePoint arrays
//

import Foundation
import PencilKit

/// Calculates instantaneous and average velocity from stroke points
enum VelocityCalculator {

    /// Calculates instantaneous velocity at each point in the stroke
    /// Velocity = sqrt((dx/dt)² + (dy/dt)²)
    /// - Parameter points: Array of PKStrokePoint from a stroke
    /// - Returns: Array of velocity values (points per second) for each point pair
    static func calculateVelocity(from points: [PKStrokePoint]) -> [Double] {
        guard points.count >= 2 else { return [] }

        var velocities: [Double] = []
        velocities.reserveCapacity(points.count - 1)

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]

            let dx = curr.location.x - prev.location.x
            let dy = curr.location.y - prev.location.y
            let dt = curr.timeOffset - prev.timeOffset

            // Avoid division by zero
            guard dt > 0 else {
                velocities.append(0)
                continue
            }

            let velocity = sqrt(dx * dx + dy * dy) / dt
            velocities.append(velocity)
        }

        return velocities
    }

    /// Calculates the average velocity across an entire stroke
    /// - Parameter points: Array of PKStrokePoint from a stroke
    /// - Returns: Average velocity in points per second
    static func averageVelocity(from points: [PKStrokePoint]) -> Double {
        let velocities = calculateVelocity(from: points)
        guard !velocities.isEmpty else { return 0 }

        return velocities.reduce(0, +) / Double(velocities.count)
    }

    /// Calculates the final velocity (last few samples) of a stroke
    /// Useful for detecting if the user slowed down before lifting
    /// - Parameters:
    ///   - points: Array of PKStrokePoint from a stroke
    ///   - sampleCount: Number of final samples to average (default 3)
    /// - Returns: Average of final velocity samples
    static func finalVelocity(from points: [PKStrokePoint], sampleCount: Int = 3) -> Double {
        let velocities = calculateVelocity(from: points)
        guard !velocities.isEmpty else { return 0 }

        let samplesToTake = min(sampleCount, velocities.count)
        let finalSamples = velocities.suffix(samplesToTake)

        return finalSamples.reduce(0, +) / Double(finalSamples.count)
    }
}
