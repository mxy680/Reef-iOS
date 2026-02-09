//
//  StudyStatsService.swift
//  Reef
//
//  Computes study statistics for the dashboard.
//

import SwiftUI

@MainActor
class StudyStatsService: ObservableObject {
    static let shared = StudyStatsService()

    // MARK: - Persisted Activity Data

    @AppStorage("studyActivityDates") private var activityDatesData: Data = Data()
    @AppStorage("weeklyStudyTimeSeconds") private var weeklyStudyTimeSeconds: Int = 0
    @AppStorage("weeklyStudyTimeStartDate") private var weeklyStudyTimeStartDate: Double = 0
    @AppStorage("problemsSolvedThisWeek") private var problemsSolvedThisWeek: Int = 0
    @AppStorage("problemsSolvedWeekStart") private var problemsSolvedWeekStart: Double = 0
    @AppStorage("aiFeedbackThisWeek") private var aiFeedbackThisWeek: Int = 0
    @AppStorage("aiFeedbackWeekStart") private var aiFeedbackWeekStart: Double = 0

    private init() {
        resetWeeklyStatsIfNeeded()
    }

    // MARK: - Activity Dates (for streak calculation)

    private var activityDates: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: activityDatesData)) ?? []
        }
        set {
            activityDatesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: - Public Stats

    var studyStreak: Int {
        calculateStreak()
    }

    var formattedStudyTime: String {
        let hours = weeklyStudyTimeSeconds / 3600
        let minutes = (weeklyStudyTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var problemsSolved: Int {
        problemsSolvedThisWeek
    }

    var aiFeedbackCount: Int {
        aiFeedbackThisWeek
    }

    func hasActivity(on date: Date) -> Bool {
        activityDates.contains(dateFormatter.string(from: date))
    }

    // MARK: - Recording Activity

    func recordActivity() {
        let dateString = dateFormatter.string(from: Date())
        var dates = activityDates
        dates.insert(dateString)
        activityDates = dates
        objectWillChange.send()
    }

    func addStudyTime(seconds: Int) {
        resetWeeklyStatsIfNeeded()
        weeklyStudyTimeSeconds += seconds
        recordActivity()
        objectWillChange.send()
    }

    func recordProblemSolved() {
        resetWeeklyStatsIfNeeded()
        problemsSolvedThisWeek += 1
        recordActivity()
        objectWillChange.send()
    }

    func recordAIFeedback() {
        resetWeeklyStatsIfNeeded()
        aiFeedbackThisWeek += 1
        recordActivity()
        objectWillChange.send()
    }

    // MARK: - Private Helpers

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func calculateStreak() -> Int {
        let dates = activityDates
        guard !dates.isEmpty else { return 0 }

        var streak = 0
        var currentDate = Date()
        let calendar = Calendar.current

        // Check if today has activity
        let todayString = dateFormatter.string(from: currentDate)
        if dates.contains(todayString) {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        } else {
            // Check if yesterday has activity (streak can continue if user studied yesterday)
            let yesterdayString = dateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: currentDate)!)
            if !dates.contains(yesterdayString) {
                return 0 // No recent activity
            }
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        // Count consecutive days backwards
        while true {
            let dateString = dateFormatter.string(from: currentDate)
            if dates.contains(dateString) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }

            // Safety limit
            if streak > 365 {
                break
            }
        }

        return streak
    }

    private func resetWeeklyStatsIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        // Get start of current week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        // Check study time
        if weeklyStudyTimeStartDate == 0 || Date(timeIntervalSince1970: weeklyStudyTimeStartDate) < weekStart {
            weeklyStudyTimeSeconds = 0
            weeklyStudyTimeStartDate = weekStart.timeIntervalSince1970
        }

        // Check problems solved
        if problemsSolvedWeekStart == 0 || Date(timeIntervalSince1970: problemsSolvedWeekStart) < weekStart {
            problemsSolvedThisWeek = 0
            problemsSolvedWeekStart = weekStart.timeIntervalSince1970
        }

        // Check AI feedback
        if aiFeedbackWeekStart == 0 || Date(timeIntervalSince1970: aiFeedbackWeekStart) < weekStart {
            aiFeedbackThisWeek = 0
            aiFeedbackWeekStart = weekStart.timeIntervalSince1970
        }
    }
}
