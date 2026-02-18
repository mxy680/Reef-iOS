//
//  WeeklyActivityView.swift
//  Reef
//
//  Monthly activity heatmap showing study activity for the current calendar month.
//

import SwiftUI

struct WeeklyActivityView: View {
    @ObservedObject var statsService: StudyStatsService
    let colorScheme: ColorScheme

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    private static let maxWeeks = 4

    /// Weeks of the current calendar month (Mon–Sun rows), capped to 4 rows.
    /// Days outside the month are nil. If the month needs 5+ rows, the earliest row is dropped.
    private var weeks: [[Date?]] {
        let calendar = Calendar.current
        let today = Date()
        let range = calendar.range(of: .day, in: .month, for: today)!
        let components = calendar.dateComponents([.year, .month], from: today)
        let firstOfMonth = calendar.date(from: components)!

        // Weekday of the 1st (convert Sun=1..Sat=7 to Mon=0..Sun=6)
        let firstWeekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7

        let totalSlots = firstWeekday + range.count
        let weekCount = Int(ceil(Double(totalSlots) / 7.0))

        let allWeeks: [[Date?]] = (0..<weekCount).map { week in
            (0..<7).map { day in
                let slot = week * 7 + day
                let dayIndex = slot - firstWeekday
                guard dayIndex >= 0, dayIndex < range.count else { return nil }
                return calendar.date(byAdding: .day, value: dayIndex, to: firstOfMonth)
            }
        }

        return Array(allWeeks.suffix(Self.maxWeeks))
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

                Spacer()

                Text(monthName)
                    .font(.quicksand(14, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
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
                            if let date = date {
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
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(colorScheme == .dark ? Color.warmDarkCard : .cardBackground)
            .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
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
