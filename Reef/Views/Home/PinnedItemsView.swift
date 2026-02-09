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
                let skeletonCount = 3 - items.count

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

                    if index < items.count - 1 || skeletonCount > 0 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }

                ForEach(0..<skeletonCount, id: \.self) { index in
                    PinnedSkeletonRow(colorScheme: colorScheme)

                    if index < skeletonCount - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 210)
            .clipped()
            .background(Color.adaptiveCardBackground(for: colorScheme))
            .dashboardCard(colorScheme: colorScheme, cornerRadius: 16)
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

// MARK: - Pinned Skeleton Row

private struct PinnedSkeletonRow: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.1))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.1))
                    .frame(width: 100, height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.07))
                    .frame(width: 60, height: 10)
            }

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
