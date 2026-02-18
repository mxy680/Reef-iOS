//
//  RecentItemsView.swift
//  Reef
//
//  Recently opened documents displayed as inline rows in a single card.
//

import SwiftUI
import SwiftData

struct RecentItemsView: View {
    @ObservedObject var userPrefs: UserPreferencesManager
    let courses: [Course]
    let colorScheme: ColorScheme
    let onSelectNote: (Note, Course) -> Void

    private var recentItems: [RecentItem] {
        var items: [RecentItem] = []

        for course in courses {
            for note in course.notes {
                if let lastOpened = note.lastOpenedAt {
                    items.append(.note(note, course, lastOpened))
                }
            }
        }

        return items
            .sorted { $0.lastOpened > $1.lastOpened }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.deepCoral)
                    .frame(width: 8, height: 8)
                Text("Recent")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }

            if recentItems.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.5))

                        Text("No recent activity yet")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .claymorphic(cornerRadius: 28, colorScheme: colorScheme)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                        RecentRowView(
                            item: item,
                            colorScheme: colorScheme,
                            onTap: {
                                switch item {
                                case .note(let note, let course, _):
                                    onSelectNote(note, course)
                                }
                            }
                        )

                        Divider()
                            .padding(.leading, 64)
                    }

                    // Placeholder rows to fill empty slots
                    if recentItems.count < 3 {
                        let placeholderCount = 3 - recentItems.count
                        ForEach(0..<placeholderCount, id: \.self) { index in
                            RecentPlaceholderView(colorScheme: colorScheme)

                            if index < placeholderCount - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
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
}

// MARK: - Recent Row View

private struct RecentRowView: View {
    let item: RecentItem
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon in rounded rect
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.deepTeal)
                    .frame(width: 40, height: 40)
                    .background(Color.seafoam.opacity(colorScheme == .dark ? 0.2 : 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Title + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                        .lineLimit(1)

                    Text(item.courseName)
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                // Relative time
                Text(item.relativeTime)
                    .font(.quicksand(12, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.7))

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Placeholder View

private struct RecentPlaceholderView: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.2))
                .frame(width: 40, height: 40)

            Text("Open a note")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.35))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Recent Item Enum

enum RecentItem: Identifiable {
    case note(Note, Course, Date)

    var id: UUID {
        switch self {
        case .note(let note, _, _): return note.id
        }
    }

    var lastOpened: Date {
        switch self {
        case .note(_, _, let date): return date
        }
    }

    var icon: String {
        switch self {
        case .note(let note, _, _): return note.fileTypeIcon
        }
    }

    var title: String {
        switch self {
        case .note(let note, _, _): return note.name
        }
    }

    var courseName: String {
        switch self {
        case .note(_, let course, _): return course.name
        }
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastOpened, relativeTo: Date())
    }
}
