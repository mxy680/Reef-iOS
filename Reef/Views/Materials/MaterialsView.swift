//
//  MaterialsView.swift
//  Reef
//

import SwiftUI
import SwiftData
import PDFKit

// MARK: - Thumbnail Cache

class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func thumbnail(for materialID: UUID) -> UIImage? {
        cache.object(forKey: materialID.uuidString as NSString)
    }

    func setThumbnail(_ image: UIImage, for materialID: UUID) {
        cache.setObject(image, forKey: materialID.uuidString as NSString)
    }

    func removeThumbnail(for materialID: UUID) {
        cache.removeObject(forKey: materialID.uuidString as NSString)
    }
}

// MARK: - Materials View

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
                materialsGrid
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

    // MARK: - Materials Grid

    private var materialsGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                ForEach(materials) { material in
                    MaterialGridItem(material: material, onDelete: { deleteMaterial(material) })
                }

                // Add new material placeholder card
                AddMaterialCard(onTap: onAddMaterial)
            }
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Actions

    private func deleteMaterial(_ material: Material) {
        ThumbnailCache.shared.removeThumbnail(for: material.id)
        try? FileStorageService.shared.deleteFile(
            materialID: material.id,
            fileExtension: material.fileExtension
        )
        modelContext.delete(material)
    }
}

// MARK: - Material Grid Item

struct MaterialGridItem: View {
    let material: Material
    let onDelete: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isShowingRenameAlert = false
    @State private var isShowingDeleteConfirmation = false
    @State private var editedName = ""

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area (9:10 aspect ratio)
            ZStack {
                (effectiveColorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97))

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else if isLoadingThumbnail {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    placeholderIcon
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(9/10, contentMode: .fit)

            // Separator between thumbnail and footer
            Rectangle()
                .fill(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15))
                .frame(height: 1)

            // Name, date, and action icons footer
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name)
                        .font(.nunito(15, weight: .semiBold))
                        .foregroundColor(Color.inkBlack)
                        .lineLimit(1)

                    Text(material.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.nunito(13, weight: .regular))
                        .foregroundColor(Color.inkBlack.opacity(0.6))
                }

                Spacer()

                // Action icons
                HStack(spacing: 4) {
                    Button {
                        editedName = material.name
                        isShowingRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.oceanMid)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(effectiveColorScheme == .dark ? Color(white: 0.12) : Color.sageMist)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .onAppear {
            loadThumbnail()
        }
        .alert("Rename Material", isPresented: $isShowingRenameAlert) {
            TextField("Name", text: $editedName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    material.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } message: {
            Text("Enter a new name for this material.")
        }
        .alert("Delete Material", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(material.name)\"? This action cannot be undone.")
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: material.fileTypeIcon)
            .font(.system(size: 36))
            .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.4))
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() {
        // Check cache first
        if let cached = ThumbnailCache.shared.thumbnail(for: material.id) {
            thumbnail = cached
            isLoadingThumbnail = false
            return
        }

        // Generate thumbnail on background thread
        Task.detached(priority: .userInitiated) {
            let fileURL = FileStorageService.shared.getFileURL(
                for: material.id,
                fileExtension: material.fileExtension
            )

            let generatedThumbnail: UIImage?

            switch material.fileType {
            case .image:
                generatedThumbnail = loadImageThumbnail(from: fileURL)
            case .pdf:
                generatedThumbnail = PDFThumbnailGenerator.generateThumbnail(
                    from: fileURL,
                    size: CGSize(width: 200, height: 200)
                )
            case .document:
                generatedThumbnail = nil
            }

            if let image = generatedThumbnail {
                ThumbnailCache.shared.setThumbnail(image, for: material.id)
            }

            await MainActor.run {
                thumbnail = generatedThumbnail
                isLoadingThumbnail = false
            }
        }
    }

    private func loadImageThumbnail(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Scale down for thumbnail
        let maxDimension: CGFloat = 200
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)

        if scale >= 1.0 {
            return image
        }

        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Add Material Card

struct AddMaterialCard: View {
    let onTap: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail area - same aspect ratio as material cards
                ZStack {
                    Color.clear

                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(9/10, contentMode: .fit)

                // Hidden separator (1px to match material cards)
                Color.clear
                    .frame(height: 1)

                // Footer area - matches material card footer height
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 53) // 12 padding top + ~29 text content + 12 padding bottom
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }
}

