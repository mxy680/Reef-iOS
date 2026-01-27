//
//  PauseContext.swift
//  Reef
//
//  Data model for pause detection events
//

import Foundation

/// Metadata about a detected pause event
struct PauseContext {
    /// Duration of the pause in seconds
    let duration: TimeInterval

    /// Number of strokes completed before this pause
    let strokeCount: Int

    /// The tool that was active when the pause occurred
    let lastTool: CanvasTool

    /// When the pause was detected
    let timestamp: Date

    /// Average velocity of the last stroke (points per second)
    let lastStrokeVelocity: Double

    init(
        duration: TimeInterval,
        strokeCount: Int,
        lastTool: CanvasTool,
        timestamp: Date = Date(),
        lastStrokeVelocity: Double = 0
    ) {
        self.duration = duration
        self.strokeCount = strokeCount
        self.lastTool = lastTool
        self.timestamp = timestamp
        self.lastStrokeVelocity = lastStrokeVelocity
    }
}
