//
//  DocumentGridItem.swift
//  Reef
//
//  Shared grid item component for Notes and Assignments
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
    var isVectorIndexed: Bool { get }
    var isProcessingForAI: Bool { get }
    var isAIReady: Bool { get }
    var isAssignmentProcessing: Bool { get }
    var isAssignment: Bool { get }
    var assignmentStatus: AssignmentStatus { get }
}

extension DocumentItem {
    var isAssignment: Bool { false }
    var assignmentStatus: AssignmentStatus { .none }
}

// Conform Note to DocumentItem
extension Note: DocumentItem {
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
    let itemType: String // "Notes" or "Assignment"

    @StateObject private var themeManager = ThemeManager.shared
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isShowingRenameAlert = false
    @State private var isShowingDeleteConfirmation = false
    @State private var editedName = ""
    @State private var extractionPulseScale: CGFloat = 1.0
    @State private var assignmentPulseScale: CGFloat = 1.0
    @State private var isPressed: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    /// Footer color — subtle seafoam tint
    private var footerColor: Color {
        effectiveColorScheme == .dark
            ? Color.warmDarkCard
            : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailArea
            Rectangle()
                .fill(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35))
                .frame(height: 1)
            footerArea
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.12 : 0.06), radius: 12, x: 0, y: 4)
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.06 : 0.03), radius: 3, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: themeManager.isDarkMode) { _, newValue in
            if let cached = ThumbnailCache.shared.thumbnail(for: document.id, isDarkMode: newValue) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    thumbnail = cached
                }
            } else if document.documentFileType == .pdf {
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadThumbnail()
                }
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

    private var thumbnailArea: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottom) {
                Color.adaptiveCardBackground(for: effectiveColorScheme)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .id(thumbnail)
                        .transition(.opacity)
                } else if isLoadingThumbnail {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    placeholderIcon
                }
            }

            statusIndicators
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4/3, contentMode: .fit)
    }

    private var statusIndicators: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if document.isAssignmentProcessing {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .scaleEffect(assignmentPulseScale)
                    .shadow(color: Color.blue.opacity(0.5), radius: 4)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                        ) {
                            assignmentPulseScale = 1.3
                        }
                    }
                    .onDisappear {
                        assignmentPulseScale = 1.0
                    }
            } else if document.isAssignment && document.assignmentStatus == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                    .shadow(color: Color.red.opacity(0.4), radius: 3)
            } else if document.isProcessingForAI {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
                    .scaleEffect(extractionPulseScale)
                    .shadow(color: Color.yellow.opacity(0.5), radius: 4)
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
        .padding(8)
    }

    private var footerArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.quicksand(13, weight: .semiBold))
                    .foregroundColor(effectiveColorScheme == .dark ? .white : Color.charcoal)
                    .lineLimit(1)

                Text(document.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.quicksand(11, weight: .regular))
                    .foregroundColor(effectiveColorScheme == .dark ? .white.opacity(0.6) : Color.charcoal.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 2) {
                Button {
                    editedName = document.name
                    isShowingRenameAlert = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(effectiveColorScheme == .dark ? .white.opacity(0.7) : .deepTeal)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    isShowingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(effectiveColorScheme == .dark ? Color.deepCoral.opacity(0.8) : .deepCoral)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(footerColor)
    }

    private var placeholderIcon: some View {
        Image(systemName: document.fileTypeIcon)
            .font(.system(size: 36))
            .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.4))
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() {
        let isDarkMode = themeManager.isDarkMode

        // Check cache first (for notes)
        if let cached = ThumbnailCache.shared.thumbnail(for: document.id, isDarkMode: isDarkMode) {
            thumbnail = cached
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

            // Pre-generate opposite theme variant so dark mode toggle is instant
            let oppositeMode = !isDarkMode
            if ThumbnailCache.shared.thumbnail(for: documentId, isDarkMode: oppositeMode) == nil {
                let oppositeThumbnail: UIImage?
                switch fileType {
                case .image:
                    oppositeThumbnail = Self.loadImageThumbnail(from: fileURL, isDarkMode: oppositeMode)
                case .pdf:
                    oppositeThumbnail = PDFThumbnailGenerator.generateThumbnail(from: fileURL, isDarkMode: oppositeMode)
                case .document:
                    oppositeThumbnail = nil
                }
                if let image = oppositeThumbnail {
                    ThumbnailCache.shared.setThumbnail(image, for: documentId, isDarkMode: oppositeMode)
                }
            }
        }
    }

    private nonisolated static func loadImageThumbnail(from url: URL, isDarkMode: Bool = false) -> UIImage? {
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
            // Fill with background color matching thumbnail area (warmDarkCard in dark mode)
            let bgColor = isDarkMode ? UIColor(red: 37/255, green: 30/255, blue: 34/255, alpha: 1) : UIColor.white
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))

            // Draw image centered
            image.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
        }
    }
}

