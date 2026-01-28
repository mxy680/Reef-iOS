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
    var questionDetectionStatus: QuestionDetectionStatus { get }
    var isVectorIndexed: Bool { get }
    var isProcessingForAI: Bool { get }
    var isAIReady: Bool { get }
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
    @State private var isPressed: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    /// Footer color matches canvas scroll background (behind the page)
    private var footerColor: Color {
        effectiveColorScheme == .dark
            ? Color(red: 18/255, green: 32/255, blue: 52/255)  // #122034
            : Color(white: 245/255)  // #F5F5F5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area (9:10 aspect ratio)
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottom) {
                    Color.adaptiveCardBackground(for: effectiveColorScheme)

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

                    // Subtle gradient fade at bottom of thumbnail
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(effectiveColorScheme == .dark ? 0.25 : 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }

                // Processing status indicator - pulsing yellow dot when processing for AI
                if document.isProcessingForAI {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 10, height: 10)
                        .scaleEffect(extractionPulseScale)
                        .shadow(color: Color.yellow.opacity(0.5), radius: 4)
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
                .fill(Color.gray.opacity(0.25))
                .frame(height: 1)

            // Name, date, and action icons footer
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.quicksand(15, weight: .semiBold))
                        .foregroundColor(effectiveColorScheme == .dark ? .white : Color.inkBlack)
                        .lineLimit(1)

                    Text(document.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .font(.quicksand(13, weight: .regular))
                        .foregroundColor(effectiveColorScheme == .dark ? .white.opacity(0.6) : Color.inkBlack.opacity(0.5))
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
                            .foregroundColor(effectiveColorScheme == .dark ? .white.opacity(0.7) : Color.inkBlack.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(footerColor)
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.08), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(effectiveColorScheme == .dark ? 0.3 : 0.04), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
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
            // Fill with background color matching thumbnail area (deepOceanCard in dark mode)
            let bgColor = isDarkMode ? UIColor(red: 19/255, green: 31/255, blue: 51/255, alpha: 1) : UIColor.white
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))

            // Draw image centered
            image.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
        }
    }
}

