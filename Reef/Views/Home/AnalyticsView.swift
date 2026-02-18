//
//  AnalyticsView.swift
//  Reef
//
//  Student-facing analytics dashboard with study effort, AI coaching insights,
//  strengths/weaknesses, and common mistakes.
//

import SwiftUI

// MARK: - Time Range

enum AnalyticsTimeRange: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
}

// MARK: - Mock Data

private struct AnalyticsMockData {
    let studyTime: String
    let streak: Int
    let problemsAttempted: Int
    let aiInteractions: Int
    let barChart: [(label: String, value: Double)]
    let coachingTotal: Int
    let coachingSpoke: Int
    let coachingSilent: Int
    let topTopics: [String]
    let strengths: [String]
    let weaknesses: [String]
    let mistakes: [(name: String, count: Int)]

    static func data(for range: AnalyticsTimeRange) -> AnalyticsMockData {
        switch range {
        case .today:
            return AnalyticsMockData(
                studyTime: "1h 15m",
                streak: 5,
                problemsAttempted: 4,
                aiInteractions: 6,
                barChart: [
                    ("9am", 0.3), ("10am", 0.5), ("11am", 0),
                    ("12pm", 0), ("1pm", 0.25), ("2pm", 0.2), ("3pm", 0)
                ],
                coachingTotal: 6,
                coachingSpoke: 5,
                coachingSilent: 1,
                topTopics: ["Quadratic equations", "Factoring"],
                strengths: ["Algebraic manipulation", "Setting up equations"],
                weaknesses: ["Sign errors in fractions", "Forgetting +C"],
                mistakes: [
                    ("Dropped negative sign", 2),
                    ("Forgot to distribute", 1)
                ]
            )
        case .thisWeek:
            return AnalyticsMockData(
                studyTime: "9h 30m",
                streak: 5,
                problemsAttempted: 18,
                aiInteractions: 23,
                barChart: [
                    ("Mon", 1.5), ("Tue", 2.0), ("Wed", 0.5),
                    ("Thu", 1.8), ("Fri", 2.5), ("Sat", 0), ("Sun", 1.2)
                ],
                coachingTotal: 23,
                coachingSpoke: 18,
                coachingSilent: 5,
                topTopics: ["Quadratic equations", "Integration by parts", "Trigonometric identities"],
                strengths: ["Algebraic manipulation", "Graph interpretation", "Setting up equations"],
                weaknesses: ["Sign errors in fractions", "Forgetting +C in integrals", "Unit conversion"],
                mistakes: [
                    ("Dropped negative sign", 7),
                    ("Forgot to distribute", 5),
                    ("Wrong trig identity", 3),
                    ("Incomplete simplification", 2)
                ]
            )
        case .thisMonth:
            return AnalyticsMockData(
                studyTime: "38h 45m",
                streak: 5,
                problemsAttempted: 72,
                aiInteractions: 89,
                barChart: [
                    ("Wk1", 8.5), ("Wk2", 10.2), ("Wk3", 11.0), ("Wk4", 9.0),
                    ("", 0), ("", 0), ("", 0)
                ],
                coachingTotal: 89,
                coachingSpoke: 71,
                coachingSilent: 18,
                topTopics: ["Integration by parts", "Quadratic equations", "Trigonometric identities", "Linear algebra"],
                strengths: ["Algebraic manipulation", "Graph interpretation", "Setting up equations"],
                weaknesses: ["Sign errors in fractions", "Forgetting +C in integrals", "Unit conversion"],
                mistakes: [
                    ("Dropped negative sign", 24),
                    ("Forgot to distribute", 18),
                    ("Wrong trig identity", 11),
                    ("Incomplete simplification", 8)
                ]
            )
        case .allTime:
            return AnalyticsMockData(
                studyTime: "142h 20m",
                streak: 5,
                problemsAttempted: 284,
                aiInteractions: 347,
                barChart: [
                    ("Oct", 28), ("Nov", 35), ("Dec", 22),
                    ("Jan", 32), ("Feb", 25), ("", 0), ("", 0)
                ],
                coachingTotal: 347,
                coachingSpoke: 278,
                coachingSilent: 69,
                topTopics: ["Integration by parts", "Quadratic equations", "Trigonometric identities", "Linear algebra"],
                strengths: ["Algebraic manipulation", "Graph interpretation", "Setting up equations"],
                weaknesses: ["Sign errors in fractions", "Forgetting +C in integrals", "Unit conversion"],
                mistakes: [
                    ("Dropped negative sign", 89),
                    ("Forgot to distribute", 64),
                    ("Wrong trig identity", 41),
                    ("Incomplete simplification", 28)
                ]
            )
        }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    let colorScheme: ColorScheme

    @State private var selectedTimeRange: AnalyticsTimeRange = .thisWeek

    private var mockData: AnalyticsMockData {
        .data(for: selectedTimeRange)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.warmDarkCard : .cardBackground
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Time Range Picker
                timeRangePicker

                // 2. Study Effort Cards
                studyEffortCards

                // 3. Daily Activity Bar Chart
                barChartSection

                // 4. AI Coaching Insights
                coachingSection

                // 5. Strengths & Weaknesses
                strengthsWeaknessesSection

                // 6. Common Mistakes
                commonMistakesSection
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    // MARK: - 1. Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.quicksand(14, weight: selectedTimeRange == range ? .semiBold : .medium))
                        .foregroundColor(
                            selectedTimeRange == range
                                ? .white
                                : Color.adaptiveText(for: colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTimeRange == range ? Color.deepTeal : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .dashboardCard(colorScheme: colorScheme, cornerRadius: 14)
    }

    // MARK: - 2. Study Effort Cards

    private var studyEffortCards: some View {
        HStack(spacing: 16) {
            BentoStatCard(
                icon: "clock.fill",
                iconColor: .deepTeal,
                value: mockData.studyTime,
                label: "study time",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "flame.fill",
                iconColor: .deepCoral,
                value: "\(mockData.streak)",
                label: "day streak",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "pencil.and.outline",
                iconColor: .deepTeal,
                value: "\(mockData.problemsAttempted)",
                label: "attempted",
                colorScheme: colorScheme
            )
            BentoStatCard(
                icon: "sparkles",
                iconColor: .deepCoral,
                value: "\(mockData.aiInteractions)",
                label: "AI chats",
                colorScheme: colorScheme
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 3. Bar Chart Section

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Study Activity", color: .deepTeal)

            AnalyticsBarChartView(
                data: mockData.barChart,
                colorScheme: colorScheme,
                highlightIndex: highlightIndex
            )
            .padding(16)
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    private var highlightIndex: Int? {
        switch selectedTimeRange {
        case .today:
            // Highlight current hour slot — just highlight the last non-zero for demo
            return 1
        case .thisWeek:
            // Highlight today's day-of-week (Mon=0..Sun=6)
            let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            return weekday
        case .thisMonth, .allTime:
            return nil
        }
    }

    // MARK: - 4. AI Coaching Insights

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "AI Coaching", color: .deepCoral)

            HStack(spacing: 20) {
                // Donut chart
                AnalyticsDonutView(
                    segments: [
                        (Double(mockData.coachingSpoke), Color.deepCoral),
                        (Double(mockData.coachingSilent), Color.seafoam)
                    ],
                    centerText: "\(mockData.coachingTotal)",
                    centerLabel: "total",
                    colorScheme: colorScheme
                )

                // Legend + top topics
                VStack(alignment: .leading, spacing: 12) {
                    // Legend
                    HStack(spacing: 16) {
                        legendItem(color: .deepCoral, label: "Spoke (\(mockData.coachingSpoke))")
                        legendItem(color: .seafoam, label: "Silent (\(mockData.coachingSilent))")
                    }

                    // Top coached topics
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Top Topics")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme))

                        ForEach(mockData.topTopics, id: \.self) { topic in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.deepTeal)
                                    .frame(width: 5, height: 5)
                                Text(topic)
                                    .font(.quicksand(14, weight: .regular))
                                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    // MARK: - 5. Strengths & Weaknesses

    private var strengthsWeaknessesSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Strengths
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Strengths", color: .deepTeal)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mockData.strengths.enumerated()), id: \.offset) { index, strength in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.deepTeal)
                            Text(strength)
                                .font(.quicksand(15, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if index < mockData.strengths.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
                .background(
                    colorScheme == .dark
                        ? Color.deepTeal.opacity(0.08)
                        : Color.seafoam.opacity(0.3)
                )
                .background(cardBackground)
                .dashboardCard(colorScheme: colorScheme)
            }

            // Weaknesses
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Areas to Improve", color: .deepCoral)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mockData.weaknesses.enumerated()), id: \.offset) { index, weakness in
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.deepCoral)
                            Text(weakness)
                                .font(.quicksand(15, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if index < mockData.weaknesses.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
                .background(
                    colorScheme == .dark
                        ? Color.deepCoral.opacity(0.08)
                        : Color.softCoral.opacity(0.15)
                )
                .background(cardBackground)
                .dashboardCard(colorScheme: colorScheme)
            }
        }
    }

    // MARK: - 6. Common Mistakes

    private var commonMistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Common Mistakes", color: .deepCoral)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(mockData.mistakes.enumerated()), id: \.offset) { index, mistake in
                    HStack(spacing: 12) {
                        // Rank badge
                        Text("#\(index + 1)")
                            .font(.quicksand(13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(index == 0 ? Color.deepCoral : Color.deepTeal.opacity(0.7))
                            )

                        Text(mistake.name)
                            .font(.quicksand(15, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: colorScheme))

                        Spacer()

                        // Frequency badge
                        Text("\(mistake.count)x")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(Color.deepCoral)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        colorScheme == .dark
                                            ? Color.deepCoral.opacity(0.15)
                                            : Color.softCoral.opacity(0.3)
                                    )
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < mockData.mistakes.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.quicksand(18, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.quicksand(13, weight: .medium))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
        }
    }
}

#Preview {
    ScrollView {
        AnalyticsView(colorScheme: .light)
    }
}
