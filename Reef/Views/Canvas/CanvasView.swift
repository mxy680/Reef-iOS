//
//  CanvasView.swift
//  Reef
//

import SwiftUI
import PDFKit

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

    // Undo/Redo state
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // Clipboard state
    @State private var canPaste: Bool = false


    // Reference to canvas for undo/redo
    @State private var canvasViewRef: CanvasContainerView?

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private func updatePasteState() {
        UIPasteboard.general.detectPatterns(for: [.init(rawValue: "com.apple.pencilkit.drawing")]) { result in
            DispatchQueue.main.async {
                if case .success(let patterns) = result {
                    canPaste = !patterns.isEmpty
                } else {
                    canPaste = false
                }
            }
        }
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
                isDarkMode: themeManager.isDarkMode,
                onCanvasReady: { canvasViewRef = $0 },
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
                    colorScheme: effectiveColorScheme,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    canPaste: canPaste,
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
                    onPaste: {
                        guard let canvas = canvasViewRef?.canvasView else { return }
                        canvas.becomeFirstResponder()
                        canvas.performPaste()
                        updatePasteState()
                    },
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
            // Check initial clipboard state
            updatePasteState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            updatePasteState()
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
