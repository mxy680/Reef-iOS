//
//  DashboardView.swift
//  Reef
//
//  Quick Dashboard home page showing stats, pinned items, and recent activity.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    let courses: [Course]
    let colorScheme: ColorScheme
    let userName: String?
    let onSelectCourse: (Course) -> Void
    let onSelectNote: (Note, Course) -> Void

    @StateObject private var statsService = StudyStatsService.shared
    @StateObject private var userPrefs = UserPreferencesManager.shared

    private var continueStudyingItem: (Note, Course)? {
        var best: (Note, Course, Date)?
        for course in courses {
            for note in course.notes {
                if let opened = note.lastOpenedAt {
                    if best == nil || opened > best!.2 {
                        best = (note, course, opened)
                    }
                }
            }
        }
        guard let best else { return nil }
        return (best.0, best.1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // === BENTO TOP ROW ===
                HStack(alignment: .top, spacing: 16) {
                    // Left: Streak tile (fills height)
                    StreakHeroBanner(
                        streak: statsService.studyStreak,
                        colorScheme: colorScheme,
                        userName: userName
                    )

                    // Right: 2 stats + AI feedback
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            BentoStatCard(
                                icon: "clock.fill",
                                iconColor: .deepTeal,
                                value: statsService.formattedStudyTime,
                                label: "study time",
                                colorScheme: colorScheme
                            )
                            BentoStatCard(
                                icon: "checkmark.circle.fill",
                                iconColor: .deepCoral,
                                value: "\(statsService.problemsSolved)",
                                label: "problems",
                                colorScheme: colorScheme
                            )
                        }
                        BentoStatCard(
                            icon: "sparkles",
                            iconColor: .deepTeal,
                            value: "\(statsService.aiFeedbackCount)",
                            label: "AI feedback",
                            colorScheme: colorScheme
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                // === WEEKLY ACTIVITY HEATMAP ===
                WeeklyActivityView(
                    statsService: statsService,
                    colorScheme: colorScheme
                )

                // === PINNED & RECENT SIDE BY SIDE ===
                HStack(alignment: .top, spacing: 16) {
                    PinnedItemsView(
                        userPrefs: userPrefs,
                        courses: courses,
                        colorScheme: colorScheme,
                        onSelectCourse: onSelectCourse,
                        onSelectNote: onSelectNote
                    )

                    RecentItemsView(
                        userPrefs: userPrefs,
                        courses: courses,
                        colorScheme: colorScheme,
                        onSelectNote: onSelectNote
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }
}

#Preview {
    DashboardView(
        courses: [],
        colorScheme: .light,
        userName: "Mark Shteyn",
        onSelectCourse: { _ in },
        onSelectNote: { _, _ in }
    )
}
