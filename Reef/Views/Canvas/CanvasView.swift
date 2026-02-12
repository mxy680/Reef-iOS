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
    @Environment(\.modelContext) private var modelContext

    // Drawing state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedPenColor: Color = UserDefaults.standard.bool(forKey: "isDarkMode") ? .white : .black
    @State private var selectedHighlighterColor: Color = Color(red: 1.0, green: 0.92, blue: 0.23) // Yellow
    @State private var penWidth: CGFloat = StrokeWidthRange.penDefault
    @State private var highlighterWidth: CGFloat = StrokeWidthRange.highlighterDefault
    @State private var eraserSize: CGFloat = StrokeWidthRange.eraserDefault
    @State private var eraserType: EraserType = .stroke
    @State private var diagramWidth: CGFloat = StrokeWidthRange.diagramDefault
    @State private var diagramAutosnap: Bool = true
    @State private var customPenColors: [Color] = []
    @State private var customHighlighterColors: [Color] = []
    @State private var canvasBackgroundMode: CanvasBackgroundMode = .normal
    @State private var canvasBackgroundOpacity: CGFloat = 0.15
    @State private var canvasBackgroundSpacing: CGFloat = 48

    // Reference to canvas
    @State private var canvasViewRef: CanvasContainerView?

    // Ruler state
    @State private var isRulerActive: Bool = false

    // Text box state
    @State private var textSize: CGFloat = 16
    @State private var textColor: Color = .black

    // Undo/redo state
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // Drawing persistence
    @State private var saveTask: Task<Void, Never>?

    // PDF export state
    @State private var isExporting: Bool = false
    @State private var exportedFileURL: URL? = nil
    @State private var showExportPreview: Bool = false

    // Assignment mode state
    @State private var viewMode: CanvasViewMode = .document
    @State private var currentQuestionIndex: Int = 0
    @State private var showTutorSidebar: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var fileURL: URL {
        FileStorageService.shared.getFileURL(
            for: note.id,
            fileExtension: note.fileExtension
        )
    }

    /// Whether assignment mode is enabled for this note
    private var isAssignmentEnabled: Bool {
        note.isAssignment && note.isAssignmentReady
    }

    /// Total number of extracted questions
    private var totalQuestions: Int {
        note.extractedQuestions.count
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top toolbar
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    selectedPenColor: $selectedPenColor,
                    selectedHighlighterColor: $selectedHighlighterColor,
                    penWidth: $penWidth,
                    highlighterWidth: $highlighterWidth,
                    eraserSize: $eraserSize,
                    eraserType: $eraserType,
                    diagramWidth: $diagramWidth,
                    diagramAutosnap: $diagramAutosnap,
                    customPenColors: $customPenColors,
                    customHighlighterColors: $customHighlighterColors,
                    canvasBackgroundMode: $canvasBackgroundMode,
                    canvasBackgroundOpacity: $canvasBackgroundOpacity,
                    canvasBackgroundSpacing: $canvasBackgroundSpacing,
                    colorScheme: effectiveColorScheme,
                    onHomePressed: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    },
                    onToggleDarkMode: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.toggle()
                        }
                        selectedPenColor = themeManager.isDarkMode ? .white : .black
                    },
                    isDocumentAIReady: note.isAIReady,
                    onAddPageAfterCurrent: {
                        canvasViewRef?.addPageAfterCurrent()
                    },
                    onAddPageToEnd: {
                        canvasViewRef?.addPageToEnd()
                    },
                    onDeleteCurrentPage: {
                        canvasViewRef?.deleteCurrentPage()
                    },
                    onDeleteLastPage: {
                        canvasViewRef?.deleteLastPage()
                    },
                    onClearCurrentPage: {
                        canvasViewRef?.clearCurrentPage()
                    },
                    onExportPDF: { exportPDF() },
                    pageCount: canvasViewRef?.pageContainers.count ?? 1,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    onUndo: { canvasViewRef?.performUndo() },
                    onRedo: { canvasViewRef?.performRedo() },
                    isAssignmentEnabled: isAssignmentEnabled,
                    viewMode: $viewMode,
                    currentQuestionIndex: currentQuestionIndex,
                    totalQuestions: totalQuestions,
                    onPreviousQuestion: {
                        if currentQuestionIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentQuestionIndex -= 1
                            }
                        }
                    },
                    onNextQuestion: {
                        if currentQuestionIndex < totalQuestions - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentQuestionIndex += 1
                            }
                        }
                    },
                    onJumpToQuestion: { index in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentQuestionIndex = index
                        }
                    },
                    isAssignmentProcessing: note.isAssignmentProcessing,
                    isTutorSidebarVisible: showTutorSidebar,
                    onToggleTutorSidebar: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTutorSidebar.toggle()
                        }
                    },
                    isRulerActive: isRulerActive,
                    onToggleRuler: { isRulerActive.toggle() },
                    onAutoZoom: { canvasViewRef?.fitToWidth() },
                    textSize: $textSize,
                    textColor: $textColor
                )

                // Content view with optional AI panel sidebar
                HStack(spacing: 0) {
                    // Content view - switches between document and assignment view
                    Group {
                        if viewMode == .assignment && isAssignmentEnabled {
                            // Assignment mode view
                            AssignmentView(
                                note: note,
                                currentIndex: currentQuestionIndex,
                                selectedTool: $selectedTool,
                                selectedPenColor: $selectedPenColor,
                                selectedHighlighterColor: $selectedHighlighterColor,
                                penWidth: $penWidth,
                                highlighterWidth: $highlighterWidth,
                                eraserSize: $eraserSize,
                                eraserType: $eraserType,
                                diagramWidth: $diagramWidth,
                                diagramAutosnap: $diagramAutosnap,
                                canvasBackgroundMode: canvasBackgroundMode,
                                canvasBackgroundOpacity: canvasBackgroundOpacity,
                                canvasBackgroundSpacing: canvasBackgroundSpacing,
                                isDarkMode: themeManager.isDarkMode,
                                isRulerActive: isRulerActive,
                                textSize: textSize,
                                textColor: UIColor(textColor),
                                onPreviousQuestion: {
                                    if currentQuestionIndex > 0 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentQuestionIndex -= 1
                                        }
                                    }
                                },
                                onNextQuestion: {
                                    if currentQuestionIndex < totalQuestions - 1 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentQuestionIndex += 1
                                        }
                                    }
                                },
                                onCanvasReady: { container in
                                    canvasViewRef = container
                                },
                                onUndoStateChanged: { canUndo = $0 },
                                onRedoStateChanged: { canRedo = $0 }
                            )
                        } else {
                            // Document view (default)
                            DrawingOverlayView(
                                documentID: note.id,
                                documentURL: fileURL,
                                fileType: note.fileType,
                                selectedTool: $selectedTool,
                                selectedPenColor: $selectedPenColor,
                                selectedHighlighterColor: $selectedHighlighterColor,
                                penWidth: $penWidth,
                                highlighterWidth: $highlighterWidth,
                                eraserSize: $eraserSize,
                                eraserType: $eraserType,
                                diagramWidth: $diagramWidth,
                                diagramAutosnap: $diagramAutosnap,
                                canvasBackgroundMode: canvasBackgroundMode,
                                canvasBackgroundOpacity: canvasBackgroundOpacity,
                                canvasBackgroundSpacing: canvasBackgroundSpacing,
                                isDarkMode: themeManager.isDarkMode,
                                isRulerActive: isRulerActive,
                                textSize: textSize,
                                textColor: UIColor(textColor),
                                onCanvasReady: { container in
                                    canvasViewRef = container
                                },
                                onUndoStateChanged: { canUndo = $0 },
                                onRedoStateChanged: { canRedo = $0 }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // AI Panel sidebar
                    if showTutorSidebar {
                        Rectangle()
                            .fill(themeManager.isDarkMode ? Color.warmDarkCard : Color.seafoam.opacity(0.25))
                            .frame(width: 320)
                            .overlay(
                                Rectangle()
                                    .fill(themeManager.isDarkMode ? Color.brightTealDark.opacity(0.3) : Color.deepTeal.opacity(0.15))
                                    .frame(width: 1),
                                alignment: .leading
                            )
                            .transition(.move(edge: .trailing))
                    }
                }
            }

            // Export loading overlay
            if isExporting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.deepTeal)
                            Text("Preparing export...")
                                .font(.quicksand(14, weight: .medium))
                                .foregroundColor(Color(white: 0.3))
                        }
                        .padding(.horizontal, 36)
                        .padding(.vertical, 28)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blushWhite)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 32, x: 0, y: 12)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExporting)
        .sheet(isPresented: $showExportPreview, onDismiss: {
            exportedFileURL = nil
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                PDFExportService.cleanupExportFiles()
            }
        }) {
            if let url = exportedFileURL {
                PDFExportPreview(url: url, colorScheme: effectiveColorScheme)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(themeManager.isDarkMode ? Color.warmDark : Color.blushWhite)
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
            // Auto-default to assignment view when assignment is ready
            if note.isAssignment && note.isAssignmentReady {
                viewMode = .assignment
            }
        }
        .onDisappear {
            // Only manage state if not controlled by parent
            if onDismiss == nil {
                columnVisibility = .all
                isViewingCanvas = false
            }
        }
        .onChange(of: currentQuestionIndex) { _, _ in }
    }

    // MARK: - PDF Export

    private func exportPDF() {
        guard !isExporting else { return }
        isExporting = true

        let safeName = note.name.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(safeName).pdf"

        Task {
            do {
                let url: URL

                if isAssignmentEnabled {
                    // Assignment mode: save current question's drawings, then export all questions
                    canvasViewRef?.saveAllDrawings()
                    url = try await PDFExportService.generateAssignmentPDF(note: note, fileName: fileName)
                } else {
                    // Document mode: export current document with annotations
                    guard let container = canvasViewRef else { throw PDFExportService.ExportError.renderingFailed }
                    container.saveAllDrawings()
                    let pages = await container.exportPageData()
                    url = try await PDFExportService.generatePDF(pages: pages, fileName: fileName)
                }

                await MainActor.run {
                    exportedFileURL = url
                    isExporting = false
                    showExportPreview = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }

}

// MARK: - PDF Export Preview

struct PDFExportPreview: View {
    let url: URL
    let colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var pageCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(white: colorScheme == .dark ? 0.4 : 0.78))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color(white: 0.92))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("Export Preview")
                        .font(.quicksand(16, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                    if pageCount > 0 {
                        Text("\(pageCount) \(pageCount == 1 ? "page" : "pages")")
                            .font(.quicksand(11, weight: .regular))
                            .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                    }
                }

                Spacer()

                // Invisible spacer to balance the X button
                Color.clear
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // PDF preview
            PDFPreviewView(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 16)

            // Share button
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share PDF")
                        .font(.quicksand(14, weight: .semiBold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.deepTeal)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .preferredColorScheme(colorScheme)
        .onAppear {
            if let doc = PDFDocument(url: url) {
                pageCount = doc.pageCount
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [url])
        }
    }
}

/// PDFView wrapper for the export preview — pages fill width, no zoom-out past fit
private struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(Color.blushWhite)
        pdfView.pageShadowsEnabled = false
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        if let document = PDFDocument(url: url) {
            pdfView.document = document

            // Lock minimum zoom to the auto-scaled level so user can't zoom out
            DispatchQueue.main.async {
                pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            }
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - PDF View

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 249/255, green: 245/255, blue: 246/255, alpha: 1)

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
