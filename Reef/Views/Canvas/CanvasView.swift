//
//  CanvasView.swift
//  Reef
//
//  Main container view for PDF annotation with PencilKit drawing overlay

import SwiftUI
import SwiftData
import PDFKit
import PencilKit

struct CanvasView: View {
    let material: Material
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel: CanvasViewModel

    // Tool state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedColor: Color = .inkBlack
    @State private var penSize: ToolSize = .medium
    @State private var highlighterSize: ToolSize = .medium
    @State private var eraserSize: ToolSize = .medium
    @State private var isShowingColorPicker = false
    @State private var isShowingOverflowMenu = false
    @State private var isShowingVersionHistory = false
    @State private var currentPageIndex: Int = 0

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    init(material: Material) {
        self.material = material
        self._viewModel = StateObject(wrappedValue: CanvasViewModel(material: material))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.adaptiveBackground(for: effectiveColorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Toolbar
                    CanvasToolbar(
                        selectedTool: $selectedTool,
                        selectedColor: $selectedColor,
                        penSize: $penSize,
                        highlighterSize: $highlighterSize,
                        eraserSize: $eraserSize,
                        isShowingColorPicker: $isShowingColorPicker,
                        isShowingOverflowMenu: $isShowingOverflowMenu,
                        canUndo: viewModel.canUndo,
                        canRedo: viewModel.canRedo,
                        isBlankCanvas: material.isBlankCanvas,
                        onBack: { dismiss() },
                        onUndo: { viewModel.undo() },
                        onRedo: { viewModel.redo() },
                        onAddPage: material.isBlankCanvas ? { _ = viewModel.addNewPage() } : nil,
                        colorScheme: effectiveColorScheme
                    )

                    // PDF + Drawing Canvas
                    if let pdfURL = viewModel.pdfURL {
                        AnnotationCanvasContainer(
                            pdfURL: pdfURL,
                            currentPageIndex: $currentPageIndex,
                            selectedTool: selectedTool,
                            selectedColor: selectedColor,
                            toolSize: currentToolSize,
                            viewModel: viewModel,
                            colorScheme: effectiveColorScheme
                        )
                    } else {
                        // Loading or error state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading document...")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.configure(with: modelContext)
            viewModel.loadDocument()
        }
        .onDisappear {
            viewModel.saveAnnotations()
        }
        .overlay {
            if isShowingColorPicker {
                ColorPalettePopover(
                    selectedColor: $selectedColor,
                    isShowing: $isShowingColorPicker,
                    colorScheme: effectiveColorScheme
                )
            }
        }
        .overlay {
            if isShowingOverflowMenu {
                OverflowMenuPopover(
                    isShowing: $isShowingOverflowMenu,
                    onExport: { viewModel.exportPDF() },
                    onVersionHistory: { isShowingVersionHistory = true },
                    colorScheme: effectiveColorScheme
                )
            }
        }
        .overlay {
            if isShowingVersionHistory {
                VersionHistoryView(
                    versions: viewModel.getVersions(),
                    onRestore: { versionId in
                        _ = viewModel.restoreVersion(versionId)
                    },
                    onDismiss: { isShowingVersionHistory = false },
                    colorScheme: effectiveColorScheme
                )
            }
        }
    }

    private var currentToolSize: ToolSize {
        switch selectedTool {
        case .pen: return penSize
        case .highlighter: return highlighterSize
        case .eraser: return eraserSize
        }
    }
}

// MARK: - Canvas Tools

enum CanvasTool: String, CaseIterable {
    case pen
    case highlighter
    case eraser

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}

enum ToolSize: String, CaseIterable {
    case fine
    case medium
    case bold

    var penWidth: CGFloat {
        switch self {
        case .fine: return 1
        case .medium: return 3
        case .bold: return 5
        }
    }

    var highlighterWidth: CGFloat {
        switch self {
        case .fine: return 8
        case .medium: return 15
        case .bold: return 25
        }
    }

    var eraserWidth: CGFloat {
        switch self {
        case .fine: return 10
        case .medium: return 20
        case .bold: return 40
        }
    }

    var displayName: String {
        switch self {
        case .fine: return "Fine"
        case .medium: return "Medium"
        case .bold: return "Bold"
        }
    }
}

// MARK: - Canvas Palette Colors

extension Color {
    // Annotation canvas colors from the plan
    static let canvasInkBlack = Color(hex: "040404")
    static let canvasDeepSea = Color(hex: "13505B")
    static let canvasVibrantTeal = Color(hex: "119DA4")
    static let canvasCoral = Color(hex: "FF6B6B")
    static let canvasSand = Color(hex: "F4A261")
    static let canvasSeaFoam = Color(hex: "90E0C0")

    static let canvasPaletteColors: [Color] = [
        .canvasInkBlack,
        .canvasDeepSea,
        .canvasVibrantTeal,
        .canvasCoral,
        .canvasSand,
        .canvasSeaFoam
    ]
}

// MARK: - Canvas View Model

@MainActor
class CanvasViewModel: ObservableObject {
    let material: Material
    @Published var pdfURL: URL?
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var drawings: [Int: PKDrawing] = [:] // Page index -> Drawing

    private var annotationService: AnnotationService?
    private var annotationRecord: AnnotationRecord?
    private var undoStack: [[Int: PKDrawing]] = []
    private var redoStack: [[Int: PKDrawing]] = []
    private let maxUndoLevels = 50

    init(material: Material) {
        self.material = material
    }

    func configure(with modelContext: ModelContext) {
        self.annotationService = AnnotationService(modelContext: modelContext)
    }

    func loadDocument() {
        // Get the file URL
        let fileURL = FileStorageService.shared.getFileURL(
            for: material.id,
            fileExtension: material.fileExtension
        )

        print("📄 Loading document: \(material.name)")
        print("📄 File extension: \(material.fileExtension)")
        print("📄 File URL: \(fileURL.path)")
        print("📄 File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")

        // Handle blank canvas - create PDF if it doesn't exist
        if material.isBlankCanvas {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                // Create blank PDF
                if let _ = DocumentConverter.shared.createBlankPDF(
                    size: DocumentConverter.defaultCanvasSize,
                    destinationURL: fileURL
                ) {
                    self.pdfURL = fileURL
                    print("📄 Created blank canvas at: \(fileURL.path)")
                }
            } else {
                self.pdfURL = fileURL
            }
        }
        // Check if we need to convert image to PDF
        else if DocumentConverter.shared.shouldConvertToPDF(fileExtension: material.fileExtension) {
            // Convert image to PDF
            let pdfFileName = "\(material.id.uuidString)_converted.pdf"
            let convertedURL = FileManager.default.temporaryDirectory.appendingPathComponent(pdfFileName)

            if let converted = DocumentConverter.shared.convertImageToPDF(from: fileURL, to: convertedURL) {
                self.pdfURL = converted
                print("📄 Converted image to PDF at: \(converted.path)")
            } else {
                // Fallback to original if conversion fails
                self.pdfURL = fileURL
                print("📄 Image conversion failed, using original")
            }
        } else {
            // PDF file - use directly
            self.pdfURL = fileURL
            print("📄 Using PDF directly: \(fileURL.path)")
        }

        // Verify PDF can be loaded
        if let url = pdfURL {
            if let doc = PDFDocument(url: url) {
                print("📄 PDF loaded successfully with \(doc.pageCount) pages")
            } else {
                print("📄 ERROR: PDFDocument failed to load from \(url.path)")
            }
        }

        // Load existing annotations
        loadAnnotations()
    }

    /// Adds a new blank page to a blank canvas
    func addNewPage() -> Bool {
        guard material.isBlankCanvas, let pdfURL = pdfURL else { return false }
        return DocumentConverter.shared.addBlankPage(to: pdfURL)
    }

    func loadAnnotations() {
        guard let service = annotationService else { return }

        let record = service.getOrCreateRecord(
            for: material.id,
            documentType: .material
        )
        self.annotationRecord = record
        self.drawings = service.getAllDrawings(for: record)
    }

    func saveAnnotations() {
        guard let service = annotationService,
              let record = annotationRecord else { return }

        service.setAllDrawings(drawings, for: record)
    }

    func undo() {
        guard !undoStack.isEmpty else { return }

        // Save current state to redo stack
        redoStack.append(drawings)

        // Restore previous state
        drawings = undoStack.removeLast()
        updateUndoRedoState()
        saveAnnotations()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }

        // Save current state to undo stack
        undoStack.append(drawings)

        // Restore next state
        drawings = redoStack.removeLast()
        updateUndoRedoState()
        saveAnnotations()
    }

    private func pushUndoState() {
        undoStack.append(drawings)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateUndoRedoState()
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    func exportPDF() {
        guard let pdfURL = pdfURL else { return }
        _ = PDFExporter.shared.exportAnnotatedPDF(
            pdfURL: pdfURL,
            drawings: drawings
        )
    }

    func getDrawing(for pageIndex: Int) -> PKDrawing {
        drawings[pageIndex] ?? PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int) {
        // Push current state to undo stack before making changes
        pushUndoState()

        drawings[pageIndex] = drawing

        // Trigger auto-save via service
        if let service = annotationService, let record = annotationRecord {
            service.setDrawing(drawing, for: pageIndex, record: record)
        }
    }

    // MARK: - Version History

    func getVersions() -> [AnnotationVersion] {
        guard let service = annotationService,
              let record = annotationRecord else { return [] }
        return service.getVersions(for: record)
    }

    func restoreVersion(_ versionId: UUID) -> Bool {
        guard let service = annotationService,
              let record = annotationRecord else { return false }

        let success = service.restoreVersion(versionId, for: record)
        if success {
            // Reload drawings from the restored record
            drawings = service.getAllDrawings(for: record)
            undoStack.removeAll()
            redoStack.removeAll()
            updateUndoRedoState()
        }
        return success
    }
}

// MARK: - Annotation Canvas Container

struct AnnotationCanvasContainer: View {
    let pdfURL: URL
    @Binding var currentPageIndex: Int
    let selectedTool: CanvasTool
    let selectedColor: Color
    let toolSize: ToolSize
    @ObservedObject var viewModel: CanvasViewModel
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Paper background
            Color.white

            // PDF Document View
            PDFDocumentView(
                url: pdfURL,
                currentPageIndex: $currentPageIndex
            )

            // Drawing Overlay - positioned over the PDF
            DrawingOverlayView(
                pageIndex: currentPageIndex,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                toolSize: toolSize,
                drawing: Binding(
                    get: { viewModel.getDrawing(for: currentPageIndex) },
                    set: { viewModel.setDrawing($0, for: currentPageIndex) }
                ),
                onDrawingChanged: { drawing in
                    viewModel.setDrawing(drawing, for: currentPageIndex)
                }
            )
        }
    }
}

// MARK: - Color Palette Popover

struct ColorPalettePopover: View {
    @Binding var selectedColor: Color
    @Binding var isShowing: Bool
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            VStack(spacing: 12) {
                Text("Colors")
                    .font(.quicksand(14, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Color.canvasPaletteColors, id: \.self) { color in
                        Button {
                            selectedColor = color
                            isShowing = false
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.vibrantTeal : Color.clear, lineWidth: 3)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.adaptiveText(for: colorScheme).opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(colorScheme == .dark ? Color.deepOcean : Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
            .frame(maxWidth: 180)
            .position(x: UIScreen.main.bounds.width - 100, y: 120)
        }
    }
}

// MARK: - Overflow Menu Popover

struct OverflowMenuPopover: View {
    @Binding var isShowing: Bool
    let onExport: () -> Void
    let onVersionHistory: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            VStack(alignment: .leading, spacing: 0) {
                MenuButton(icon: "square.and.arrow.up", title: "Export PDF") {
                    onExport()
                    isShowing = false
                }

                Divider()

                MenuButton(icon: "clock.arrow.circlepath", title: "Version History") {
                    onVersionHistory()
                    isShowing = false
                }
            }
            .background(colorScheme == .dark ? Color.deepOcean : Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
            .frame(width: 180)
            .position(x: UIScreen.main.bounds.width - 100, y: 120)
        }
    }

    struct MenuButton: View {
        let icon: String
        let title: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                    Text(title)
                        .font(.quicksand(14, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
