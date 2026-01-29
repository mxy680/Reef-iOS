//
//  PauseDetector.swift
//  Reef
//
//  Core algorithm for detecting user pauses during drawing
//

import Foundation
import PencilKit

/// Detects when users pause while writing/drawing
/// Uses velocity analysis and stroke completion rate to determine pauses
final class PauseDetector {

    // MARK: - Configuration

    /// Minimum pause duration before triggering (in seconds)
    private let minimumPauseDuration: TimeInterval = 0.8

    /// Window for tracking stroke rate (in seconds)
    private let strokeRateWindow: TimeInterval = 2.0

    /// Check interval for pause detection (in seconds)
    private let checkInterval: TimeInterval = 0.1

    /// Tools that should trigger pause detection
    private static let activeTools: Set<CanvasTool> = [.pen, .highlighter]

    // MARK: - State

    /// Timestamps of recently completed strokes (within rolling window)
    private var strokeTimestamps: [Date] = []

    /// Total strokes completed since reset
    private var totalStrokeCount: Int = 0

    /// Last stroke velocity for context
    private var lastStrokeVelocity: Double = 0

    /// Time of last activity (stroke completion or tool use)
    private var lastActivityTime: Date?

    /// Current tool being used
    private var currentTool: CanvasTool = .pen

    /// Whether user is currently scrolling/zooming
    private var isScrolling: Bool = false

    /// Whether we're currently in a pause state
    private var isPaused: Bool = false

    /// Timer for periodic pause checks
    private var checkTimer: Timer?

    // MARK: - Callbacks

    /// Called when a pause is detected
    var onPauseDetected: ((PauseContext) -> Void)?

    // MARK: - Initialization

    init() {
        startTimer()
    }

    deinit {
        stopTimer()
    }

    // MARK: - Public Methods

    /// Record a stroke completion event
    /// - Parameter stroke: The completed PKStroke
    func recordStrokeCompleted(stroke: PKStroke) {
        let points = stroke.path.map { $0 }
        lastStrokeVelocity = VelocityCalculator.averageVelocity(from: points)

        let now = Date()
        strokeTimestamps.append(now)
        totalStrokeCount += 1
        lastActivityTime = now

        // Reset pause state when user starts drawing again
        isPaused = false

        // Clean up old timestamps outside the window
        pruneOldTimestamps()
    }

    /// Record when a tool usage ends
    func recordToolEnded() {
        lastActivityTime = Date()
    }

    /// Update the current state
    /// - Parameters:
    ///   - currentTool: The currently selected tool
    ///   - isScrolling: Whether the user is scrolling/zooming
    func update(currentTool: CanvasTool, isScrolling: Bool) {
        let toolChanged = self.currentTool != currentTool
        self.currentTool = currentTool
        self.isScrolling = isScrolling

        // Reset activity time when tool changes (user is doing something)
        if toolChanged {
            lastActivityTime = Date()
            isPaused = false
        }
    }

    /// Reset all state (e.g., when switching documents)
    func reset() {
        strokeTimestamps.removeAll()
        totalStrokeCount = 0
        lastStrokeVelocity = 0
        lastActivityTime = nil
        isPaused = false
    }

    // MARK: - Private Methods

    private func startTimer() {
        checkTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForPause()
        }
    }

    private func stopTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func pruneOldTimestamps() {
        let cutoff = Date().addingTimeInterval(-strokeRateWindow)
        strokeTimestamps.removeAll { $0 < cutoff }
    }

    private func checkForPause() {
        // Filter: Only active for pen and highlighter
        guard Self.activeTools.contains(currentTool) else { return }

        // Filter: Ignore during scrolling/zooming
        guard !isScrolling else { return }

        // Need at least one stroke to detect pauses
        guard totalStrokeCount > 0 else { return }

        // Need a last activity time
        guard let lastActivity = lastActivityTime else { return }

        // Calculate time since last activity
        let timeSinceActivity = Date().timeIntervalSince(lastActivity)

        // Check if we've exceeded the minimum pause duration
        guard timeSinceActivity >= minimumPauseDuration else { return }

        // Calculate stroke rate (strokes per second in the window)
        pruneOldTimestamps()
        let strokeRate = Double(strokeTimestamps.count) / strokeRateWindow

        // Pause condition: velocity ≈ 0 (pen lifted) AND stroke rate ≈ 0
        // Since pen is lifted when we get stroke completion, we just check stroke rate
        let isPauseConditionMet = strokeRate < 0.5  // Less than 1 stroke per 2 seconds

        guard isPauseConditionMet else { return }

        // Avoid firing multiple times for the same pause
        guard !isPaused else { return }

        // Mark as paused and fire callback
        isPaused = true

        let context = PauseContext(
            duration: timeSinceActivity,
            strokeCount: totalStrokeCount,
            lastTool: currentTool,
            lastStrokeVelocity: lastStrokeVelocity
        )

        onPauseDetected?(context)
    }
}
