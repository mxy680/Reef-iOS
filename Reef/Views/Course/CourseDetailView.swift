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
    @State private var isInitialLoad: Bool = true

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

    // Recent notes (sorted by lastOpenedAt, limit 7)
    private var recentNotes: [Note] {
        course.notes
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(7)
            .map { $0 }
    }

    var body: some View {
        Group {
            if isInitialLoad {
                skeletonView
            } else {
                courseContent
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

    private var courseContent: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    searchBar

                    if !debouncedSearchText.isEmpty {
                        searchResultsView
                    } else {
                        bentoTopRow
                        recentNotesSection()
                    }
                }
                .padding(32)
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    debouncedSearchText = newValue
                }
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search bar skeleton
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                        .frame(width: 16, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                        .frame(height: 16)
                }
                .padding(16)
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.04), radius: 8, x: 0, y: 2)

                // Bento top row skeleton
                HStack(spacing: 16) {
                    // Hero card placeholder
                    ZStack {
                        Color.adaptiveCardBackground(for: colorScheme)
                        SkeletonShimmerView(colorScheme: colorScheme)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                    // Stacked cards placeholder
                    VStack(spacing: 16) {
                        skeletonBentoCard
                        skeletonBentoCard
                    }
                }
                .frame(height: 290)

                // Recent section skeleton
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                            .frame(width: 8, height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                            .frame(width: 60, height: 16)
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                                        .frame(width: 140, height: 14)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                                        .frame(width: 80, height: 12)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            if index < 6 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .background(Color.adaptiveCardBackground(for: colorScheme))
                    .dashboardCard(colorScheme: colorScheme, cornerRadius: 16)
                }
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
    }

    private var skeletonBentoCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.12))
                    .frame(width: 30, height: 24)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.08))
                    .frame(width: 60, height: 13)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.warmDarkCard : .white)
        .dashboardCard(colorScheme: colorScheme)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))

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
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Bento Top Row

    private var bentoTopRow: some View {
        HStack(spacing: 16) {
            // Left: Notes hero card
            NotesHeroCard(
                count: course.notes.count,
                colorScheme: colorScheme,
                onTap: { onSelectSubPage("notes") }
            )

            // Right: Quizzes + Exams stacked
            VStack(spacing: 16) {
                BentoContentCard(
                    title: "Quizzes",
                    icon: "list.bullet.clipboard",
                    count: course.quizzes.count,
                    colorScheme: colorScheme,
                    onTap: { onSelectSubPage("quizzes") }
                )
                BentoContentCard(
                    title: "Exams",
                    icon: "doc.text.magnifyingglass",
                    count: 0,
                    colorScheme: colorScheme,
                    onTap: { onSelectSubPage("exams") }
                )
            }
        }
        .frame(height: 290)
    }

    // MARK: - Recent Notes Section

    // top padding + search bar + spacing + bento row + spacing + header spacing + bottom padding

    private func recentNotesSection() -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            // Header with coral dot (matching dashboard style)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.deepCoral)
                    .frame(width: 8, height: 8)
                Text("Recent")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                Spacer()

                if !recentNotes.isEmpty {
                    Button {
                        onSelectSubPage("notes")
                    } label: {
                        Text("View All")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }

            if course.notes.isEmpty {
                // Empty state — no notes in course
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.4))

                    Text("No notes yet")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))

                    Text("Add a note to get started")
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 476)
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .dashboardCard(colorScheme: colorScheme, cornerRadius: 16)
            } else {
                // Recent notes list with placeholder fill
                VStack(spacing: 0) {
                    ForEach(Array(recentNotes.enumerated()), id: \.element.id) { index, note in
                        Button {
                            onSelectNote(note)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: note.fileTypeIcon)
                                    .font(.system(size: 18))
                                    .foregroundColor(.deepTeal)
                                    .frame(width: 40, height: 40)
                                    .background(Color.seafoam.opacity(colorScheme == .dark ? 0.2 : 0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.name)
                                        .font(.quicksand(16, weight: .medium))
                                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                                        .lineLimit(1)

                                    if let lastOpened = note.lastOpenedAt {
                                        Text(lastOpened.relativeFormatted)
                                            .font(.quicksand(13, weight: .regular))
                                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                                    }
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

                        Divider()
                            .padding(.leading, 64)
                    }

                    // Placeholder rows to fill empty slots
                    if recentNotes.count < 7 {
                        let placeholderCount = 7 - recentNotes.count
                        ForEach(0..<placeholderCount, id: \.self) { index in
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

                            if index < placeholderCount - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .background(Color.adaptiveCardBackground(for: colorScheme))
                .dashboardCard(colorScheme: colorScheme, cornerRadius: 16)
            }
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
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme).opacity(0.4))

                    Text("No results found")
                        .font(.quicksand(18, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))

                    Text("Try a different search term")
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
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
                                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))

                            Spacer()

                            Button {
                                onSelectSubPage("notes")
                            } label: {
                                Text("View All")
                                    .font(.quicksand(14, weight: .medium))
                                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
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

// MARK: - Notes Hero Card

struct NotesHeroCard: View {
    let count: Int
    let colorScheme: ColorScheme
    let onTap: () -> Void

    @State private var animatedCount: Int = 0

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "2A5A5A"), .deepTeal]
                : [.seafoam, .deepTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Top: icon
                HStack(alignment: .top) {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer(minLength: 0)

                // Bottom: count + label
                Text("\(animatedCount)")
                    .font(.dynaPuff(64, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text("notes")
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Text("View all \(Image(systemName: "arrow.right"))")
                    .font(.quicksand(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 2)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.4), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedCount = count
            }
        }
        .onChange(of: count) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCount = newValue
            }
        }
    }
}

// MARK: - Bento Content Card

struct BentoContentCard: View {
    let title: String
    let icon: String
    let count: Int
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color.warmDarkCard : .white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.deepTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.quicksand(28, weight: .bold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(title.lowercased())
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cardBackground)
            .dashboardCard(colorScheme: colorScheme)
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
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
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
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.3))
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
