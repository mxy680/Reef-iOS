//
//  MaterialsView.swift
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

    func thumbnail(for materialID: UUID, isDarkMode: Bool = false) -> UIImage? {
        cache.object(forKey: cacheKey(for: materialID, isDarkMode: isDarkMode))
    }

    func setThumbnail(_ image: UIImage, for materialID: UUID, isDarkMode: Bool = false) {
        cache.setObject(image, forKey: cacheKey(for: materialID, isDarkMode: isDarkMode))
    }

    func removeThumbnail(for materialID: UUID) {
        // Remove both light and dark variants
        cache.removeObject(forKey: cacheKey(for: materialID, isDarkMode: false))
        cache.removeObject(forKey: cacheKey(for: materialID, isDarkMode: true))
    }
}

// MARK: - Materials View

struct MaterialsView: View {
    let course: Course
    let onAddMaterial: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    // Filter state
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var sortNewestFirst: Bool = true
    @State private var hybridSearchResults: [UUID]? = nil
    @State private var isSearching: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var materials: [Material] {
        course.materials.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var filteredMaterials: [Material] {
        // If no search query, return all materials sorted by date
        if debouncedSearchText.isEmpty {
            return course.materials.sorted {
                sortNewestFirst ? $0.dateAdded > $1.dateAdded : $0.dateAdded < $1.dateAdded
            }
        }

        // If hybrid search results are available, use them (already ranked by relevance)
        if let searchResults = hybridSearchResults {
            let materialMap = Dictionary(uniqueKeysWithValues: course.materials.map { ($0.id, $0) })
            return searchResults.compactMap { materialMap[$0] }
        }

        // Fallback: simple keyword filter while hybrid search is running
        return course.materials.filter { material in
            material.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
            (material.extractedText?.localizedCaseInsensitiveContains(debouncedSearchText) ?? false)
        }.sorted {
            sortNewestFirst ? $0.dateAdded > $1.dateAdded : $0.dateAdded < $1.dateAdded
        }
    }

    var body: some View {
        Group {
            if materials.isEmpty {
                emptyStateView
            } else {
                materialsGrid
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(action: onAddMaterial)
                .padding(.trailing, 24)
                .padding(.bottom, 12)
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if !Task.isCancelled {
                    await performHybridSearch(query: newValue)
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
                Text("No materials yet")
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Add your first material to get started")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onAddMaterial()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Material")
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

    // MARK: - Materials Grid

    private var materialsGrid: some View {
        VStack(spacing: 0) {
            FilterBar(searchText: $searchText, sortNewestFirst: $sortNewestFirst, placeholder: "Search notes...")

            ScrollView {
                if filteredMaterials.isEmpty && !debouncedSearchText.isEmpty {
                    noResultsView
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                        ForEach(filteredMaterials) { material in
                            DocumentGridItem(document: material, onDelete: { deleteMaterial(material) }, itemType: "Material")
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

            Text("No materials found")
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
    private func performHybridSearch(query: String) async {
        debouncedSearchText = query

        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hybridSearchResults = nil
            isSearching = false
            return
        }

        isSearching = true

        let results = await HybridSearchService.shared.searchMaterials(
            query: query,
            materials: Array(course.materials),
            courseId: course.id
        )

        // Only update if this is still the current search
        if debouncedSearchText == query {
            hybridSearchResults = results.isEmpty ? nil : results
            isSearching = false
        }
    }

    // MARK: - Actions

    private func deleteMaterial(_ material: Material) {
        ThumbnailCache.shared.removeThumbnail(for: material.id)
        try? FileStorageService.shared.deleteFile(
            materialID: material.id,
            fileExtension: material.fileExtension
        )

        // Remove from vector index
        let materialId = material.id
        Task {
            try? await RAGService.shared.deleteDocument(documentId: materialId)
        }

        modelContext.delete(material)
    }
}
