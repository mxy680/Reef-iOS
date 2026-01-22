//
//  DocumentGridItem.swift
//  Reef
//
//  Shared grid item component for Materials and Assignments
//

import SwiftUI
import PDFKit

// MARK: - Thumbnail Configuration

/// Fixed thumbnail size for consistent card dimensions (9:10 aspect ratio)
private let thumbnailSize = CGSize(width: 180, height: 200)

// MARK: - Document Protocol

enum DocumentFileType: String {
    case pdf, image, document
}

protocol DocumentItem: AnyObject {
    var id: UUID { get }
    var name: String { get set }
    var fileName: String { get }
    var fileExtension: String { get }
    var dateAdded: Date { get }
    var fileTypeIcon: String { get }
    var documentFileType: DocumentFileType { get }
    var extractionStatus: ExtractionStatus { get }
}

// Conform Material to DocumentItem
extension Material: DocumentItem {
    var documentFileType: DocumentFileType {
        switch fileType {
        case .pdf: return .pdf
        case .image: return .image
        case .document: return .document
        }
    }
}

// Conform Assignment to DocumentItem
extension Assignment: DocumentItem {
    var documentFileType: DocumentFileType {
        switch fileType {
        case .pdf: return .pdf
        case .image: return .image
        case .document: return .document
        }
    }
}

// MARK: - Document Grid Item

struct DocumentGridItem<T: DocumentItem>: View {
    let document: T
    let onDelete: () -> Void
    let onTap: (() -> Void)?
    let itemType: String // "Material" or "Assignment"

    init(document: T, onDelete: @escaping () -> Void, onTap: (() -> Void)? = nil, itemType: String) {
        self.document = document
        self.onDelete = onDelete
        self.onTap = onTap
        self.itemType = itemType
    }

    @StateObject private var themeManager = ThemeManager.shared
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isShowingRenameAlert = false
    @State private var isShowingDeleteConfirmation = false
    @State private var editedName = ""
    @State private var extractionPulseScale: CGFloat = 1.0

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area (9:10 aspect ratio)
            ZStack(alignment: .topTrailing) {
                ZStack {
                    (effectiveColorScheme == .dark ? Color.deepOcean : Color(white: 0.97))

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

                // Extraction status indicator - pulsing teal dot when extracting
                if document.extractionStatus == .extracting {
                    Circle()
                        .fill(Color.vibrantTeal)
                        .frame(width: 10, height: 10)
                        .scaleEffect(extractionPulseScale)
                        .shadow(color: Color.vibrantTeal.opacity(0.5), radius: 4)
                        .padding(8)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                            ) {
                                extractionPulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            extractionPulseScale = 1.0
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(9/10, contentMode: .fill)

            // Separator between thumbnail and footer
            Rectangle()
                .fill(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15))
                .frame(height: 1)

            // Name, date, and action icons footer
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.quicksand(15, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        .lineLimit(1)

                    Text(document.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                }

                Spacer()

                // Action icons
                HStack(spacing: 4) {
                    Button {
                        editedName = document.name
                        isShowingRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(effectiveColorScheme == .dark ? .white : Color.oceanMid)
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
            .background(effectiveColorScheme == .dark ? Color.deepOcean : Color.sageMist)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.08), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.3 : 0.04), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: themeManager.isDarkMode) { _, _ in
            // Reload thumbnail when theme changes (for PDFs)
            if document.documentFileType == .pdf {
                loadThumbnail()
            }
        }
        .alert("Rename \(itemType)", isPresented: $isShowingRenameAlert) {
            TextField("Name", text: $editedName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    document.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } message: {
            Text("Enter a new name for this \(itemType.lowercased()).")
        }
        .alert("Delete \(itemType)", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(document.name)\"? This action cannot be undone.")
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: document.fileTypeIcon)
            .font(.system(size: 36))
            .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.4))
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() {
        let isDarkMode = themeManager.isDarkMode

        // Check cache first (for materials)
        if let cached = ThumbnailCache.shared.thumbnail(for: document.id, isDarkMode: isDarkMode) {
            thumbnail = cached
            isLoadingThumbnail = false
            return
        }

        // Check stored thumbnail data (for assignments) - only for light mode
        // Dark mode thumbnails are always generated fresh
        if !isDarkMode,
           let assignment = document as? Assignment,
           let thumbnailData = assignment.thumbnailData,
           let image = UIImage(data: thumbnailData) {
            thumbnail = image
            isLoadingThumbnail = false
            return
        }

        // Capture values before entering detached task (Swift 6 concurrency)
        let documentId = document.id
        let fileExtension = document.fileExtension
        let fileType = document.documentFileType

        // Generate thumbnail on background thread
        Task.detached(priority: .userInitiated) {
            let fileURL = FileStorageService.shared.getFileURL(
                for: documentId,
                fileExtension: fileExtension
            )

            let generatedThumbnail: UIImage?

            switch fileType {
            case .image:
                generatedThumbnail = Self.loadImageThumbnail(from: fileURL, isDarkMode: isDarkMode)
            case .pdf:
                generatedThumbnail = PDFThumbnailGenerator.generateThumbnail(from: fileURL, isDarkMode: isDarkMode)
            case .document:
                generatedThumbnail = nil
            }

            if let image = generatedThumbnail {
                ThumbnailCache.shared.setThumbnail(image, for: documentId, isDarkMode: isDarkMode)
            }

            await MainActor.run {
                thumbnail = generatedThumbnail
                isLoadingThumbnail = false
            }
        }
    }

    private static func loadImageThumbnail(from url: URL, isDarkMode: Bool = false) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Scale image to fit within fixed thumbnail size while maintaining aspect ratio
        let scale = min(thumbnailSize.width / image.size.width, thumbnailSize.height / image.size.height)
        let scaledWidth = image.size.width * scale
        let scaledHeight = image.size.height * scale

        // Center the scaled image on the fixed-size canvas
        let xOffset = (thumbnailSize.width - scaledWidth) / 2
        let yOffset = (thumbnailSize.height - scaledHeight) / 2

        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { context in
            // Fill with background color matching the thumbnail area (Deep Ocean in dark mode)
            let bgColor = isDarkMode ? UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1) : UIColor(white: 0.97, alpha: 1)
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))

            // Draw image centered
            image.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
        }
    }
}

