//
//  AssignmentsView.swift
//  Reef
//

import SwiftUI
import SwiftData

// MARK: - Assignments View

struct AssignmentsView: View {
    let course: Course
    let onAddAssignment: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    // Filter state
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var sortNewestFirst: Bool = true

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var assignments: [Assignment] {
        course.assignments.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var filteredAssignments: [Assignment] {
        var result = course.assignments

        // Filter by search text (searches name and PDF content)
        if !debouncedSearchText.isEmpty {
            result = result.filter { assignment in
                assignment.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                (assignment.extractedText?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
            }
        }

        // Sort by date
        return result.sorted {
            sortNewestFirst ? $0.dateAdded > $1.dateAdded : $0.dateAdded < $1.dateAdded
        }
    }

    var body: some View {
        Group {
            if assignments.isEmpty {
                emptyStateView
            } else {
                assignmentsGrid
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(action: onAddAssignment)
                .padding(.trailing, 24)
                .padding(.bottom, 12)
        }
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.6))

            VStack(spacing: 8) {
                Text("No assignments yet")
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Add your first assignment to get started")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onAddAssignment()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Assignment")
                        .font(.quicksand(16, weight: .semiBold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.vibrantTeal)
                .cornerRadius(12)
                .shadow(color: Color.vibrantTeal.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Assignments Grid

    private var assignmentsGrid: some View {
        VStack(spacing: 0) {
            FilterBar(searchText: $searchText, sortNewestFirst: $sortNewestFirst, placeholder: "Search assignments...")

            ScrollView {
                if filteredAssignments.isEmpty && !debouncedSearchText.isEmpty {
                    noResultsView
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                        ForEach(filteredAssignments) { assignment in
                            DocumentGridItem(document: assignment, onDelete: { deleteAssignment(assignment) }, itemType: "Assignment")
                        }
                    }
                    .padding(32)
                }
            }
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.4))

            Text("No assignments found")
                .font(.quicksand(18, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            Text("Try a different search term")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Actions

    private func deleteAssignment(_ assignment: Assignment) {
        try? FileStorageService.shared.deleteFile(
            materialID: assignment.id,
            fileExtension: assignment.fileExtension
        )

        // Remove from vector index
        let assignmentId = assignment.id
        Task {
            try? await RAGService.shared.deleteDocument(documentId: assignmentId)
        }

        modelContext.delete(assignment)
    }
}
