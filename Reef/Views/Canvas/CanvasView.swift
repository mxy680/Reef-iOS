//
//  CanvasView.swift
//  Reef
//

import SwiftUI
import PDFKit
import PencilKit

struct CanvasView: View {
    let note: Note
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var isViewingCanvas: Bool
    var onDismiss: (() -> Void)? = nil
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    // Drawing state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedPenColor: Color = UserDefaults.standard.bool(forKey: "isDarkMode") ? .white : .black
    @State private var selectedHighlighterColor: Color = Color(red: 1.0, green: 0.92, blue: 0.23) // Yellow
    @State private var penWidth: CGFloat = StrokeWidthRange.penDefault
    @State private var highlighterWidth: CGFloat = StrokeWidthRange.highlighterDefault
    @State private var eraserSize: CGFloat = StrokeWidthRange.eraserDefault
    @State private var eraserType: EraserType = .stroke
    @State private var customPenColors: [Color] = []
    @State private var customHighlighterColors: [Color] = []
    @State private var canvasBackgroundMode: CanvasBackgroundMode = .normal
    @State private var canvasBackgroundOpacity: CGFloat = 0.15
    @State private var canvasBackgroundSpacing: CGFloat = 48

    // Undo/Redo state
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // Reference to canvas for undo/redo
    @State private var canvasViewRef: CanvasContainerView?

    // Drawing persistence
    @State private var saveTask: Task<Void, Never>?

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var fileURL: URL {
        FileStorageService.shared.getFileURL(
            for: note.id,
            fileExtension: note.fileExtension
        )
    }

    var body: some View {
        ZStack {
            // Document with drawing canvas overlay
            DrawingOverlayView(
                documentURL: fileURL,
                fileType: note.fileType,
                selectedTool: $selectedTool,
                selectedPenColor: $selectedPenColor,
                selectedHighlighterColor: $selectedHighlighterColor,
                penWidth: $penWidth,
                highlighterWidth: $highlighterWidth,
                eraserSize: $eraserSize,
                eraserType: $eraserType,
                canvasBackgroundMode: canvasBackgroundMode,
                canvasBackgroundOpacity: canvasBackgroundOpacity,
                canvasBackgroundSpacing: canvasBackgroundSpacing,
                isDarkMode: themeManager.isDarkMode,
                onCanvasReady: { container in
                    canvasViewRef = container
                    // Load saved drawing after canvas is ready
                    if let drawing = DrawingStorageService.shared.loadDrawing(for: note.id) {
                        container.canvasView.drawing = drawing
                    }
                },
                onUndoStateChanged: { canUndo = $0 },
                onRedoStateChanged: { canRedo = $0 }
            )

            // Floating toolbar at bottom
            VStack {
                Spacer()
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    selectedPenColor: $selectedPenColor,
                    selectedHighlighterColor: $selectedHighlighterColor,
                    penWidth: $penWidth,
                    highlighterWidth: $highlighterWidth,
                    eraserSize: $eraserSize,
                    eraserType: $eraserType,
                    customPenColors: $customPenColors,
                    customHighlighterColors: $customHighlighterColors,
                    canvasBackgroundMode: $canvasBackgroundMode,
                    canvasBackgroundOpacity: $canvasBackgroundOpacity,
                    canvasBackgroundSpacing: $canvasBackgroundSpacing,
                    colorScheme: effectiveColorScheme,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onHomePressed: {
                        if let onDismiss = onDismiss {
                            // Use parent-controlled animation
                            onDismiss()
                        } else {
                            // Fallback for navigation-based usage
                            dismiss()
                        }
                    },
                    onUndo: { canvasViewRef?.canvasView.undoManager?.undo() },
                    onRedo: { canvasViewRef?.canvasView.undoManager?.redo() },
                    onAIPressed: { /* TODO: Implement AI assistant */ },
                    onToggleDarkMode: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.toggle()
                        }
                        // Update pen color to match new theme
                        selectedPenColor = themeManager.isDarkMode ? .white : .black
                    }
                )
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .background(themeManager.isDarkMode ? Color.black : Color(white: 0.96))
        .preferredColorScheme(effectiveColorScheme)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Only manage state if not controlled by parent (onDismiss provided)
            if onDismiss == nil {
                columnVisibility = .detailOnly
                isViewingCanvas = true
            }
            // Set default pen color based on theme
            selectedPenColor = themeManager.isDarkMode ? .white : .black
        }
        .onDisappear {
            // Only manage state if not controlled by parent
            if onDismiss == nil {
                columnVisibility = .all
                isViewingCanvas = false
            }
        }
    }
}

// MARK: - PDF View

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground

        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Image Document View

struct ImageDocumentView: View {
    let url: URL
    let colorScheme: ColorScheme
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                } else {
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        Task.detached {
            guard let data = try? Data(contentsOf: url),
                  let loadedImage = UIImage(data: data) else { return }

            await MainActor.run {
                image = loadedImage
            }
        }
    }
}

// MARK: - Unsupported Document View

struct UnsupportedDocumentView: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: colorScheme).opacity(0.5))

            Text("Unsupported document type")
                .font(.quicksand(18, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
