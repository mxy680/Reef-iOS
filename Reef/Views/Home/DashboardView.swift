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

    @State private var isInitialLoad: Bool = true

    private var totalCharCount: Int {
        courses.reduce(0) { total, course in
            total + course.notes.reduce(0) { noteTotal, note in
                noteTotal + (note.extractedText?.count ?? 0)
            }
        }
    }

    private var formattedCharCount: String {
        if totalCharCount >= 1_000_000 {
            return String(format: "%.1fM", Double(totalCharCount) / 1_000_000)
        } else if totalCharCount >= 1_000 {
            return String(format: "%.1fk", Double(totalCharCount) / 1_000)
        }
        return "\(totalCharCount)"
    }

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
        Group {
            if isInitialLoad {
                skeletonView
            } else {
                dashboardContent
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
        }
    }

    private var dashboardContent: some View {
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
                            icon: "character.cursor.ibeam",
                            iconColor: .deepTeal,
                            value: formattedCharCount,
                            label: "characters",
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

            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }
    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                skeletonTopRow
                skeletonActivitySection
                HStack(alignment: .top, spacing: 16) {
                    skeletonListCard
                    skeletonListCard
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    private var skeletonTopRow: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Color.adaptiveCardBackground(for: colorScheme)
                SkeletonShimmerView(colorScheme: colorScheme)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .claymorphic(cornerRadius: 28, colorScheme: colorScheme)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    skeletonStatCard
                    skeletonStatCard
                }
                skeletonStatCard
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var skeletonActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 70, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 60, height: 14)
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 12)
                    }
                }

                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorScheme == .dark
                                    ? Color.white.opacity(0.06)
                                    : Color.adaptiveSecondary(for: colorScheme).opacity(0.1))
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                    }
                }
            }
            .padding(14)
            .background(colorScheme == .dark ? Color.warmDarkCard : .cardBackground)
            .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
        }
    }

    private var skeletonStatCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 50, height: 20)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 70, height: 13)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.warmDarkCard : .cardBackground)
        .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
    }

    private var skeletonListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 60, height: 16)
            }

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                                .frame(width: 120, height: 14)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                                .frame(width: 80, height: 12)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if index < 2 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 210)
            .clipped()
            .background(Color.adaptiveCardBackground(for: colorScheme))
            .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
        }
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
