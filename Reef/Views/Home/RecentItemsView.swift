//
//  RecentItemsView.swift
//  Reef
//
//  Vertical list showing recently opened documents.
//

import SwiftUI
import SwiftData

struct RecentItemsView: View {
    @ObservedObject var userPrefs: UserPreferencesManager
    let courses: [Course]
    let colorScheme: ColorScheme
    let onSelectNote: (Note, Course) -> Void
    let onSelectAssignment: (Assignment, Course) -> Void

    private var recentItems: [RecentItem] {
        var items: [RecentItem] = []

        for course in courses {
            // Add notes with lastOpenedAt
            for note in course.notes {
                if let lastOpened = note.lastOpenedAt {
                    items.append(.note(note, course, lastOpened))
                }
            }

            // Add assignments with lastOpenedAt
            for assignment in course.assignments {
                if let lastOpened = assignment.lastOpenedAt {
                    items.append(.assignment(assignment, course, lastOpened))
                }
            }
        }

        // Sort by most recent and limit to 10
        return items
            .sorted { $0.lastOpened > $1.lastOpened }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Recent")
                .font(.quicksand(20, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            if recentItems.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.5))

                        Text("No recent activity yet")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Vertical list
                VStack(spacing: 0) {
                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                        RecentItemRow(
                            item: item,
                            colorScheme: colorScheme,
                            isPinned: isPinned(item),
                            onTap: {
                                switch item {
                                case .note(let note, let course, _):
                                    onSelectNote(note, course)
                                case .assignment(let assignment, let course, _):
                                    onSelectAssignment(assignment, course)
                                }
                            },
                            onPin: {
                                switch item {
                                case .note(let note, _, _):
                                    userPrefs.togglePin(id: note.id)
                                case .assignment(let assignment, _, _):
                                    userPrefs.togglePin(id: assignment.id)
                                }
                            }
                        )

                        if index < recentItems.count - 1 {
                            Divider()
                                .background(Color.adaptiveSecondary(for: colorScheme).opacity(0.2))
                        }
                    }
                }
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func isPinned(_ item: RecentItem) -> Bool {
        switch item {
        case .note(let note, _, _):
            return userPrefs.isPinned(id: note.id)
        case .assignment(let assignment, _, _):
            return userPrefs.isPinned(id: assignment.id)
        }
    }
}

enum RecentItem: Identifiable {
    case note(Note, Course, Date)
    case assignment(Assignment, Course, Date)

    var id: UUID {
        switch self {
        case .note(let note, _, _): return note.id
        case .assignment(let assignment, _, _): return assignment.id
        }
    }

    var lastOpened: Date {
        switch self {
        case .note(_, _, let date): return date
        case .assignment(_, _, let date): return date
        }
    }

    var icon: String {
        switch self {
        case .note(let note, _, _): return note.fileTypeIcon
        case .assignment(let assignment, _, _): return assignment.fileTypeIcon
        }
    }

    var title: String {
        switch self {
        case .note(let note, _, _): return note.name
        case .assignment(let assignment, _, _): return assignment.name
        }
    }

    var courseName: String {
        switch self {
        case .note(_, let course, _): return course.name
        case .assignment(_, let course, _): return course.name
        }
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastOpened, relativeTo: Date())
    }
}

struct RecentItemRow: View {
    let item: RecentItem
    let colorScheme: ColorScheme
    let isPinned: Bool
    let onTap: () -> Void
    let onPin: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail/icon
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.vibrantTeal)
                    .frame(width: 48, height: 48)
                    .background(Color.adaptiveBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title and course name
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                        .lineLimit(1)

                    Text(item.courseName)
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()

                // Relative timestamp
                Text(item.relativeTime)
                    .font(.quicksand(12, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondary(for: colorScheme))

                // Pin button
                Button(action: onPin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 16))
                        .foregroundColor(isPinned ? .vibrantTeal : Color.adaptiveSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
