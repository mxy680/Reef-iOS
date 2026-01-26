//
//  PinnedItemsView.swift
//  Reef
//
//  Horizontal scrolling section showing pinned courses and notes.
//

import SwiftUI
import SwiftData

struct PinnedItemsView: View {
    @ObservedObject var userPrefs: UserPreferencesManager
    let courses: [Course]
    let colorScheme: ColorScheme
    let onSelectCourse: (Course) -> Void
    let onSelectNote: (Note, Course) -> Void
    let onSelectAssignment: (Assignment, Course) -> Void

    private var pinnedItems: [PinnedItem] {
        var items: [PinnedItem] = []

        for course in courses {
            // Check if course is pinned
            if userPrefs.isPinned(id: course.id) {
                items.append(.course(course))
            }

            // Check pinned notes in this course
            for note in course.notes {
                if userPrefs.isPinned(id: note.id) {
                    items.append(.note(note, course))
                }
            }

            // Check pinned assignments in this course
            for assignment in course.assignments {
                if userPrefs.isPinned(id: assignment.id) {
                    items.append(.assignment(assignment, course))
                }
            }
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Pinned")
                .font(.quicksand(20, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            if pinnedItems.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "pin.slash")
                            .font(.system(size: 32))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.5))

                        Text("Pin your favorite courses and notes for quick access")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Vertical list
                VStack(spacing: 0) {
                    ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                        PinnedItemRow(
                            item: item,
                            colorScheme: colorScheme,
                            onTap: {
                                switch item {
                                case .course(let course):
                                    onSelectCourse(course)
                                case .note(let note, let course):
                                    onSelectNote(note, course)
                                case .assignment(let assignment, let course):
                                    onSelectAssignment(assignment, course)
                                }
                            }
                        )

                        if index < pinnedItems.count - 1 {
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
}

enum PinnedItem: Identifiable {
    case course(Course)
    case note(Note, Course)
    case assignment(Assignment, Course)

    var id: UUID {
        switch self {
        case .course(let course): return course.id
        case .note(let note, _): return note.id
        case .assignment(let assignment, _): return assignment.id
        }
    }

    var icon: String {
        switch self {
        case .course(let course): return course.icon
        case .note(let note, _): return note.fileTypeIcon
        case .assignment(let assignment, _): return assignment.fileTypeIcon
        }
    }

    var title: String {
        switch self {
        case .course(let course): return course.name
        case .note(let note, _): return note.name
        case .assignment(let assignment, _): return assignment.name
        }
    }

    var subtitle: String? {
        switch self {
        case .course: return nil
        case .note(_, let course): return course.name
        case .assignment(_, let course): return course.name
        }
    }
}

struct PinnedItemRow: View {
    let item: PinnedItem
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.vibrantTeal)
                    .frame(width: 48, height: 48)
                    .background(Color.adaptiveBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                            .lineLimit(1)
                    } else {
                        Text("Course")
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
