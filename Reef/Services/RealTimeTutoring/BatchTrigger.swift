//
//  BatchTrigger.swift
//  Reef
//
//  Debounce-based trigger that fires 2s after the last drawing activity
//  (stroke added or erased). Ensures screenshots are only sent on pauses.
//

import Foundation

/// Fires a callback when a batch of strokes should be sent (after a drawing pause).
final class BatchTrigger {

    // MARK: - Configuration

    private let config: BatchTriggerConfig

    // MARK: - State

    /// Whether any drawing changes have occurred since the last batch
    private var hasChanges: Bool = false

    /// Timestamp of the most recent drawing activity
    private var lastActivityTime: Date = Date()

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
        lastActivityTime = Date()
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

    /// Record that drawing activity occurred (stroke added or erased).
    /// Resets the debounce timer so the batch fires after the configured
    /// interval of inactivity.
    func recordActivity() {
        lastActivityTime = Date()
        hasChanges = true
    }

    /// Record that a batch was sent (resets the changes flag)
    func recordBatchSent() {
        hasChanges = false
    }

    /// Reset all state
    func reset() {
        hasChanges = false
        lastActivityTime = Date()
    }

    // MARK: - Private

    private func checkConditions() {
        guard hasChanges,
              Date().timeIntervalSince(lastActivityTime) >= config.interval else { return }
        fire()
    }

    private func fire() {
        onBatchReady?()
    }
}
