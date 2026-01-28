//
//  CourseDetailView.swift
//  Reef
//
//  Course landing page with search bar and cards for Notes, Quizzes, and Exams.
//

import SwiftUI
import SwiftData

struct CourseDetailView: View {
    let course: Course
    let colorScheme: ColorScheme
    let onSelectSubPage: (String) -> Void
    let onSelectNote: (Note) -> Void

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    private var notesCount: Int {
        course.notes.count
    }

    // Search results
    private var filteredNotes: [Note] {
        guard !debouncedSearchText.isEmpty else { return [] }
        return course.notes.filter { note in
            note.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
            (note.extractedText?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
        }
    }

    // Recent notes (sorted by lastOpenedAt, limit 5)
    private var recentNotes: [Note] {
        course.notes
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Search Bar
                searchBar

                // Content Cards or Search Results
                if !debouncedSearchText.isEmpty {
                    searchResultsView
                } else {
                    contentCards

                    // Recent Notes Section
                    if !recentNotes.isEmpty {
                        recentNotesSection
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if !Task.isCancelled {
                    debouncedSearchText = newValue
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Color.adaptiveSecondary(for: colorScheme))

            TextField("Search notes, quizzes, and exams...", text: $searchText)
                .font(.quicksand(16, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncedSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveText(for: colorScheme).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Content Cards

    private var contentCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            // Notes Card
            ContentCard(
                title: "Notes",
                icon: "doc.text",
                count: course.notes.count,
                colorScheme: colorScheme,
                onTap: { onSelectSubPage("notes") }
            )

            // Quizzes Card
            ContentCard(
                title: "Quizzes",
                icon: "list.bullet.clipboard",
                count: 0, // TODO: Add quizzes count when Quiz model is available
                colorScheme: colorScheme,
                onTap: { onSelectSubPage("quizzes") }
            )

            // Exams Card
            ContentCard(
                title: "Exams",
                icon: "doc.text.magnifyingglass",
                count: 0, // TODO: Add exams count when Exam model is available
                colorScheme: colorScheme,
                onTap: { onSelectSubPage("exams") }
            )
        }
    }

    // MARK: - Recent Notes Section

    private var recentNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Recent Documents")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                Spacer()

                Button {
                    onSelectSubPage("notes")
                } label: {
                    Text("View All")
                        .font(.quicksand(14, weight: .medium))
                        .foregroundColor(.vibrantTeal)
                }
                .buttonStyle(.plain)
            }

            // Recent notes list
            VStack(spacing: 0) {
                ForEach(Array(recentNotes.enumerated()), id: \.element.id) { index, note in
                    Button {
                        onSelectNote(note)
                    } label: {
                        HStack(spacing: 12) {
                            // Icon
                            Image(systemName: note.fileTypeIcon)
                                .font(.system(size: 18))
                                .foregroundColor(.vibrantTeal)
                                .frame(width: 40, height: 40)
                                .background(Color.adaptiveBackground(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Title and date
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.name)
                                    .font(.quicksand(16, weight: .medium))
                                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                                    .lineLimit(1)

                                if let lastOpened = note.lastOpenedAt {
                                    Text(lastOpened.relativeFormatted)
                                        .font(.quicksand(13, weight: .regular))
                                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.3))
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < recentNotes.count - 1 {
                        Divider()
                            .background(Color.adaptiveSecondary(for: colorScheme).opacity(0.2))
                    }
                }
            }
            .background(Color.adaptiveCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredNotes.isEmpty {
                // No results
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.4))

                    Text("No results found")
                        .font(.quicksand(18, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))

                    Text("Try a different search term")
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                // Notes Results
                if !filteredNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.quicksand(18, weight: .semiBold))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))

                            Text("(\(filteredNotes.count))")
                                .font(.quicksand(14, weight: .regular))
                                .foregroundColor(Color.adaptiveSecondary(for: colorScheme))

                            Spacer()

                            Button {
                                onSelectSubPage("notes")
                            } label: {
                                Text("View All")
                                    .font(.quicksand(14, weight: .medium))
                                    .foregroundColor(.vibrantTeal)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(filteredNotes.prefix(5)) { note in
                            Button {
                                onSelectNote(note)
                            } label: {
                                SearchResultRow(
                                    title: note.name,
                                    subtitle: "Note",
                                    icon: note.fileTypeIcon,
                                    colorScheme: colorScheme
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Content Card

struct ContentCard: View {
    let title: String
    let icon: String
    let count: Int
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.vibrantTeal)

                // Title
                Text(title)
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                // Count
                Text("\(count) items")
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.adaptiveCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.vibrantTeal)
                .frame(width: 40, height: 40)
                .background(Color.adaptiveBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.quicksand(14, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.3))
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Date Extension

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    CourseDetailView(
        course: Course(name: "Test Course"),
        colorScheme: .light,
        onSelectSubPage: { _ in },
        onSelectNote: { _ in }
    )
}
