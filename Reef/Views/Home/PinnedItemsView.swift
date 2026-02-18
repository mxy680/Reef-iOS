//
//  PinnedItemsView.swift
//  Reef
//
//  Pinned courses and notes displayed as inline rows in a single card.
//

import SwiftUI
import SwiftData

struct PinnedItemsView: View {
    @ObservedObject var userPrefs: UserPreferencesManager
    let courses: [Course]
    let colorScheme: ColorScheme
    let onSelectCourse: (Course) -> Void
    let onSelectNote: (Note, Course) -> Void

    private var pinnedItems: [PinnedItem] {
        var items: [PinnedItem] = []

        for course in courses {
            if userPrefs.isPinned(id: course.id) {
                items.append(.course(course))
            }

            for note in course.notes {
                if userPrefs.isPinned(id: note.id) {
                    items.append(.note(note, course))
                }
            }
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.deepCoral)
                    .frame(width: 8, height: 8)
                Text("Pinned")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
            }

            VStack(spacing: 0) {
                let items = Array(pinnedItems.prefix(3))

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PinnedRowView(
                        item: item,
                        colorScheme: colorScheme,
                        onTap: {
                            switch item {
                            case .course(let course):
                                onSelectCourse(course)
                            case .note(let note, let course):
                                onSelectNote(note, course)
                            }
                        }
                    )

                    Divider()
                        .padding(.leading, 64)
                }

                // Placeholder rows to fill empty slots
                if items.count < 3 {
                    let placeholderCount = 3 - items.count
                    ForEach(0..<placeholderCount, id: \.self) { index in
                        PlaceholderSlotView(colorScheme: colorScheme)

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

// MARK: - Pinned Row View

private struct PinnedRowView: View {
    let item: PinnedItem
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

                    Text(item.subtitle ?? "Course")
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()

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

// MARK: - Placeholder Slot View

private struct PlaceholderSlotView: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.2))
                .frame(width: 40, height: 40)

            Text("Pin a course")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.35))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Pinned Item Enum

enum PinnedItem: Identifiable {
    case course(Course)
    case note(Note, Course)

    var id: UUID {
        switch self {
        case .course(let course): return course.id
        case .note(let note, _): return note.id
        }
    }

    var icon: String {
        switch self {
        case .course(let course): return course.icon
        case .note(let note, _): return note.fileTypeIcon
        }
    }

    var title: String {
        switch self {
        case .course(let course): return course.name
        case .note(let note, _): return note.name
        }
    }

    var subtitle: String? {
        switch self {
        case .course: return nil
        case .note(_, let course): return course.name
        }
    }
}
