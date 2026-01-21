//
//  MaterialsView.swift
//  Reef
//

import SwiftUI
import SwiftData

struct MaterialsView: View {
    let course: Course
    let onAddMaterial: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var materials: [Material] {
        course.materials.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        Group {
            if materials.isEmpty {
                emptyStateView
            } else {
                materialsList
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
                    .font(.nunito(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Add your first material to get started")
                    .font(.nunito(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onAddMaterial()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Material")
                        .font(.nunito(16, weight: .semiBold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.vibrantTeal)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Materials List

    private var materialsList: some View {
        List {
            ForEach(materials) { material in
                MaterialListItem(material: material)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .onDelete(perform: deleteMaterials)
        }
        .listStyle(.plain)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteMaterials(at offsets: IndexSet) {
        for index in offsets {
            let material = materials[index]
            try? FileStorageService.shared.deleteFile(
                materialID: material.id,
                fileExtension: material.fileExtension
            )
            modelContext.delete(material)
        }
    }
}

// MARK: - Material List Item

struct MaterialListItem: View {
    let material: Material
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            Image(systemName: material.fileTypeIcon)
                .font(.system(size: 24))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                .frame(width: 40)

            // Name and date
            VStack(alignment: .leading, spacing: 4) {
                Text(material.name)
                    .font(.nunito(16, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    .lineLimit(1)

                Text(material.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    .font(.nunito(12, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.adaptiveBackground(for: effectiveColorScheme))
    }
}
