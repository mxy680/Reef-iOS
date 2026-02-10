//
//  BatchTrigger.swift
//  Reef
//
//  Timer-based trigger that fires when any of three conditions is met:
//  1. Pending stroke count >= threshold
//  2. Time since last send >= maxTime (with pending >= 1)
//  3. Time since pencil lift >= liftDelay (with pending >= 1)
//
//  Mirrors the PauseDetector timer pattern.
//

import Foundation

/// Fires a callback when a batch of strokes should be sent.
final class BatchTrigger {

    // MARK: - Configuration

    private let config: BatchTriggerConfig

    // MARK: - State

    /// Number of strokes pending since last batch
    private var pendingStrokeCount: Int = 0

    /// When the last batch was sent (or when tracking started)
    private var lastSendTime: Date = Date()

    /// When the pencil last lifted (last stroke completed)
    private var lastPencilLiftTime: Date?

    /// Timer for periodic condition checks
    private var checkTimer: Timer?

    /// Whether the trigger is active
    private(set) var isActive: Bool = false

    // MARK: - Callback

    /// Called when a batch should be fired
    var onBatchReady: (() -> Void)?

    // MARK: - Lifecycle

    init(config: BatchTriggerConfig = .default) {
        self.config = config
    }

    deinit {
        stop()
    }

    /// Start the trigger timer
    func start() {
        guard !isActive else { return }
        isActive = true
        lastSendTime = Date()
        let timer = Timer(timeInterval: config.checkInterval, repeats: true) { [weak self] _ in
            self?.checkConditions()
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    /// Stop the trigger timer
    func stop() {
        isActive = false
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Public Methods

    /// Record that a new stroke was added to the pending buffer
    func recordStrokeAdded() {
        pendingStrokeCount += 1
        lastPencilLiftTime = Date()
    }

    /// Record that a batch was sent (resets counters)
    func recordBatchSent() {
        pendingStrokeCount = 0
        lastSendTime = Date()
        lastPencilLiftTime = nil
    }

    /// Reset all state
    func reset() {
        pendingStrokeCount = 0
        lastSendTime = Date()
        lastPencilLiftTime = nil
    }

    // MARK: - Private

    private func checkConditions() {
        guard pendingStrokeCount > 0 else { return }

        // Single condition: pencil lifted for >= liftDelay
        if let liftTime = lastPencilLiftTime {
            let timeSinceLift = Date().timeIntervalSince(liftTime)
            if timeSinceLift >= config.pencilLiftDelay {
                fire()
            }
        }
    }

    private func fire() {
        onBatchReady?()
    }
}
