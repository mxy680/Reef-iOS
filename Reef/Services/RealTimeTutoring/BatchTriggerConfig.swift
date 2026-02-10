//
//  BatchTriggerConfig.swift
//  Reef
//
//  Configurable thresholds for the hybrid batch trigger.
//

import Foundation

/// Configuration for the three-condition batch trigger.
struct BatchTriggerConfig {
    /// Trigger when pending strokes reach this count
    var strokeCountThreshold: Int = 6

    /// Trigger when time since last send exceeds this (seconds), if pending >= 1
    var maxTimeSinceLastSend: TimeInterval = 1.5

    /// Trigger when time since pencil lift exceeds this (seconds), if pending >= 1
    var pencilLiftDelay: TimeInterval = 1.0

    /// How often to check trigger conditions (seconds)
    var checkInterval: TimeInterval = 0.1

    static let `default` = BatchTriggerConfig()
}
