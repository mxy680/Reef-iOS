//
//  NotesView.swift
//  Reef
//

import SwiftUI
import SwiftData

// MARK: - Thumbnail Cache

class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200  // Increased to accommodate light/dark variants
    }

    private func cacheKey(for id: UUID, isDarkMode: Bool) -> NSString {
        "\(id.uuidString)_\(isDarkMode ? "dark" : "light")" as NSString
    }

    func thumbnail(for noteID: UUID, isDarkMode: Bool = false) -> UIImage? {
        cache.object(forKey: cacheKey(for: noteID, isDarkMode: isDarkMode))
    }

    func setThumbnail(_ image: UIImage, for noteID: UUID, isDarkMode: Bool = false) {
        cache.setObject(image, forKey: cacheKey(for: noteID, isDarkMode: isDarkMode))
    }

    func removeThumbnail(for noteID: UUID) {
        // Remove both light and dark variants
        cache.removeObject(forKey: cacheKey(for: noteID, isDarkMode: false))
        cache.removeObject(forKey: cacheKey(for: noteID, isDarkMode: true))
    }
}

// MARK: - Notes View

struct NotesView: View {
    let course: Course
    let onAddNote: () -> Void
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var isViewingCanvas: Bool
    @Binding var selectedNote: Note?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    // Filter state
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var sortNewestFirst: Bool = true
    @State private var semanticSearchResults: [UUID]? = nil  // Ordered by relevance
    @State private var isSearching: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var notes: [Note] {
        course.notes.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var filteredNotes: [Note] {
        var result = course.notes

        // If we have semantic search results, use those (ordered by relevance)
        if let semanticResults = semanticSearchResults, !debouncedSearchText.isEmpty {
            // Create a lookup for ordering
            let orderMap = Dictionary(uniqueKeysWithValues: semanticResults.enumerated().map { ($1, $0) })

            // Filter to only notes in semantic results, maintaining relevance order
            result = result
                .filter { orderMap[$0.id] != nil }
                .sorted { (orderMap[$0.id] ?? Int.max) < (orderMap[$1.id] ?? Int.max) }

            return result
        }

        // Fallback to text search if semantic search not available
        if !debouncedSearchText.isEmpty {
            result = result.filter { note in
                note.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                (note.extractedText?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
            }
        }

        // Sort by date
        return result.sorted {
            sortNewestFirst ? $0.dateAdded > $1.dateAdded : $0.dateAdded < $1.dateAdded
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                emptyStateView
            } else {
                notesGrid
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(action: onAddNote)
                .padding(.trailing, 24)
                .padding(.bottom, 12)
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if !Task.isCancelled {
                    await performSearch(query: newValue)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.6))

            VStack(spacing: 8) {
                Text("No notes yet")
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Add your first note to get started")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onAddNote()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Notes")
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

    // MARK: - Notes Grid

    private var notesGrid: some View {
        VStack(spacing: 0) {
            FilterBar(searchText: $searchText, sortNewestFirst: $sortNewestFirst, placeholder: "Search notes...")

            ScrollView {
                if filteredNotes.isEmpty && !debouncedSearchText.isEmpty {
                    noResultsView
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                        ForEach(filteredNotes) { note in
                            Button {
                                note.lastOpenedAt = Date()
                                withAnimation(.easeOut(duration: 0.3)) {
                                    selectedNote = note
                                }
                            } label: {
                                DocumentGridItem(
                                    document: note,
                                    onDelete: { deleteNote(note) },
                                    itemType: "Notes"
                                )
                            }
                            .buttonStyle(.plain)
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

            Text("No notes found")
                .font(.quicksand(18, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            Text("Try a different search term")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Search

    @MainActor
    private func performSearch(query: String) async {
        debouncedSearchText = query

        // Clear semantic results if query is empty
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            semanticSearchResults = nil
            isSearching = false
            return
        }

        isSearching = true

        do {
            // Perform semantic search via RAG
            let context = try await RAGService.shared.getContext(
                query: query,
                courseId: course.id,
                topK: 20,  // Get more results for better coverage
                maxTokens: 8000
            )

            // Extract unique document IDs in order of relevance
            var seenIds = Set<UUID>()
            var orderedIds: [UUID] = []
            for source in context.sources {
                if !seenIds.contains(source.documentId) {
                    seenIds.insert(source.documentId)
                    orderedIds.append(source.documentId)
                }
            }

            print("[NotesView] Semantic search found \(orderedIds.count) relevant documents")
            semanticSearchResults = orderedIds

        } catch {
            print("[NotesView] Semantic search failed: \(error), falling back to text search")
            semanticSearchResults = nil
        }

        isSearching = false
    }

    // MARK: - Actions

    private func deleteNote(_ note: Note) {
        ThumbnailCache.shared.removeThumbnail(for: note.id)
        try? FileStorageService.shared.deleteFile(
            documentID: note.id,
            fileExtension: note.fileExtension
        )

        // Delete associated drawing
        DrawingStorageService.shared.deleteDrawing(for: note.id)

        // Remove from vector index
        let noteId = note.id
        Task {
            try? await RAGService.shared.deleteDocument(documentId: noteId)
        }

        modelContext.delete(note)
    }
}
