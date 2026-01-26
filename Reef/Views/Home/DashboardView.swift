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
    let onSelectCourse: (Course) -> Void
    let onSelectNote: (Note, Course) -> Void
    let onSelectAssignment: (Assignment, Course) -> Void

    @StateObject private var statsService = StudyStatsService.shared
    @StateObject private var userPrefs = UserPreferencesManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats Row
                StatsRowView(
                    statsService: statsService,
                    colorScheme: colorScheme
                )

                // Pinned Items Section
                PinnedItemsView(
                    userPrefs: userPrefs,
                    courses: courses,
                    colorScheme: colorScheme,
                    onSelectCourse: onSelectCourse,
                    onSelectNote: onSelectNote,
                    onSelectAssignment: onSelectAssignment
                )

                // Recent Items Section
                RecentItemsView(
                    userPrefs: userPrefs,
                    courses: courses,
                    colorScheme: colorScheme,
                    onSelectNote: onSelectNote,
                    onSelectAssignment: onSelectAssignment
                )

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }
}

#Preview {
    DashboardView(
        courses: [],
        colorScheme: .light,
        onSelectCourse: { _ in },
        onSelectNote: { _, _ in },
        onSelectAssignment: { _, _ in }
    )
}
