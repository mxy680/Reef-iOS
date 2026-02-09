//
//  WeeklyActivityView.swift
//  Reef
//
//  Monthly activity heatmap showing study activity for the past 4 weeks.
//

import SwiftUI

struct WeeklyActivityView: View {
    @ObservedObject var statsService: StudyStatsService
    let colorScheme: ColorScheme

    private static let weekCount = 4
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    /// 4 weeks of dates, each week Mon–Sun, most recent week last.
    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -mondayOffset, to: today)!
        let startMonday = calendar.date(byAdding: .day, value: -7 * (Self.weekCount - 1), to: thisMonday)!

        return (0..<Self.weekCount).map { week in
            (0..<7).map { day in
                calendar.date(byAdding: .day, value: week * 7 + day, to: startMonday)!
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.deepCoral)
                    .frame(width: 8, height: 8)
                Text("Activity")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }

            VStack(spacing: 4) {
                // Day letter headers
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayLetters[i])
                            .font(.quicksand(10, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Week rows
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            let active = statsService.hasActivity(on: date)
                            let isFuture = date > Date()
                            let isToday = Calendar.current.isDateInToday(date)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(squareColor(active: active, isFuture: isFuture))
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isToday ? Color.deepCoral : .clear, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }
            .padding(14)
            .background(colorScheme == .dark ? Color.warmDarkCard : .white)
            .dashboardCard(colorScheme: colorScheme)
        }
    }

    private func squareColor(active: Bool, isFuture: Bool) -> Color {
        if isFuture {
            return colorScheme == .dark
                ? Color.white.opacity(0.03)
                : Color.adaptiveSecondary(for: colorScheme).opacity(0.06)
        }
        if active {
            return colorScheme == .dark ? .deepCoral : .softCoral.opacity(0.45)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.adaptiveSecondary(for: colorScheme).opacity(0.1)
    }
}
