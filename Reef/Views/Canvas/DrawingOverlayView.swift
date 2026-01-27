//
//  DrawingOverlayView.swift
//  Reef
//
//  PencilKit canvas overlay for document annotation
//

import SwiftUI
import PencilKit
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Result of a recognition operation
struct RecognitionResult {
    /// The recognized text content
    let text: String
    /// The LaTeX representation (for math content)
    let latex: String?
    /// Raw JIIX JSON for stroke mapping
    let jiix: String
    /// Number of strokes processed
    let strokeCount: Int
}

struct DrawingOverlayView: UIViewRepresentable {
    let documentID: UUID
    let documentURL: URL
    let fileType: Note.FileType
    @Binding var selectedTool: CanvasTool
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    @Binding var diagramWidth: CGFloat
    var canvasBackgroundMode: CanvasBackgroundMode = .normal
    var canvasBackgroundOpacity: CGFloat = 0.15
    var canvasBackgroundSpacing: CGFloat = 48
    var isDarkMode: Bool = false
    var recognitionEnabled: Bool = false
    var pauseSensitivity: Double = 0.5
    var questionRegions: DocumentQuestionRegions? = nil
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }
    var onRecognitionResult: (RecognitionResult) -> Void = { _ in }
    var onDrawingChanged: (PKDrawing) -> Void = { _ in }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentID: documentID, documentURL: documentURL, fileType: fileType, backgroundMode: canvasBackgroundMode, backgroundOpacity: canvasBackgroundOpacity, backgroundSpacing: canvasBackgroundSpacing, isDarkMode: isDarkMode, questionRegions: questionRegions)
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged
        context.coordinator.onRecognitionResult = onRecognitionResult
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.pauseSensitivity = pauseSensitivity

        // Set up delegates for all page canvases after a brief delay
        let initialColor = UIColor(selectedPenColor)
        let width = penWidth
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Set delegate and tool for all page canvases
            for pageContainer in container.pageContainers {
                pageContainer.canvasView.delegate = context.coordinator
                pageContainer.canvasView.tool = PKInkingTool(.pen, color: initialColor, width: width)
            }
            self.onCanvasReady(container)
        }

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        context.coordinator.currentTool = selectedTool
        context.coordinator.currentPenColor = UIColor(selectedPenColor)
        context.coordinator.currentPenWidth = penWidth

        // Update tool for all page canvases
        for pageContainer in container.pageContainers {
            // Set delegate if not already set (for newly added pages)
            if pageContainer.canvasView.delegate == nil {
                pageContainer.canvasView.delegate = context.coordinator
            }
            updateTool(pageContainer.canvasView)
        }

        container.updateDarkMode(isDarkMode)
        container.updateBackgroundMode(canvasBackgroundMode)
        container.updateBackgroundOpacity(canvasBackgroundOpacity)
        container.updateBackgroundSpacing(canvasBackgroundSpacing)

        // Keep recognition settings in sync
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.pauseSensitivity = pauseSensitivity
        context.coordinator.onRecognitionResult = onRecognitionResult
    }

    private func updateTool(_ canvasView: PKCanvasView) {
        switch selectedTool {
        case .pen:
            // Convert SwiftUI Color to UIColor using explicit RGB to avoid color scheme adaptation
            let uiColor = uiColorFromSwiftUIColor(selectedPenColor)
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: penWidth)
        case .highlighter:
            let uiColor = UIColor(selectedHighlighterColor).withAlphaComponent(0.3)
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: highlighterWidth * 3)
        case .eraser:
            switch eraserType {
            case .stroke:
                canvasView.tool = PKEraserTool(.vector)
            case .bitmap:
                canvasView.tool = PKEraserTool(.bitmap, width: eraserSize)
            }
        case .lasso:
            canvasView.tool = PKLassoTool()
        case .diagram:
            let uiColor = uiColorFromSwiftUIColor(selectedPenColor)
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: diagramWidth)
        }
    }

    /// Converts SwiftUI Color to UIColor
    /// Since the canvas container has overrideUserInterfaceStyle = .light,
    /// PencilKit won't invert colors and we can use UIColor directly
    private func uiColorFromSwiftUIColor(_ color: Color) -> UIColor {
        return UIColor(color)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var container: CanvasContainerView?
        var onUndoStateChanged: (Bool) -> Void = { _ in }
        var onRedoStateChanged: (Bool) -> Void = { _ in }
        var onRecognitionResult: (RecognitionResult) -> Void = { _ in }
        var onDrawingChanged: (PKDrawing) -> Void = { _ in }

        // Drawing change debounce
        private var drawingChangeTask: Task<Void, Never>?

        // Recognition state
        var recognitionEnabled: Bool = false
        var pauseSensitivity: Double = 0.5

        // Tool state
        var currentTool: CanvasTool = .pen {
            didSet {
                updatePauseDetectorState()
            }
        }
        var currentPenColor: UIColor = .black
        var currentPenWidth: CGFloat = 4.0

        // Pause detection
        private let pauseDetector = PauseDetector()
        private var previousStrokeCount: Int = 0

        override init() {
            super.init()
            setupPauseDetector()
        }

        private func setupPauseDetector() {
            pauseDetector.onPauseDetected = { [weak self] context in
                self?.handlePauseDetected(context)
            }
        }

        private func handlePauseDetected(_ context: PauseContext) {
            print("[PauseDetector] Pause detected: \(String(format: "%.1f", context.duration))s after \(context.strokeCount) strokes (tool: \(context.lastTool), velocity: \(String(format: "%.1f", context.lastStrokeVelocity)) pts/s)")
        }

        private func updatePauseDetectorState() {
            let isScrolling = container?.scrollView.isDragging == true ||
                              container?.scrollView.isDecelerating == true ||
                              container?.scrollView.isZooming == true
            pauseDetector.update(currentTool: currentTool, isScrolling: isScrolling)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)

            // Detect new strokes for pause detection
            let currentStrokeCount = canvasView.drawing.strokes.count
            if currentStrokeCount > previousStrokeCount,
               let latestStroke = canvasView.drawing.strokes.last {
                pauseDetector.recordStrokeCompleted(stroke: latestStroke)
            }
            previousStrokeCount = currentStrokeCount

            // Debounced save callback (500ms)
            drawingChangeTask?.cancel()
            drawingChangeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if !Task.isCancelled {
                    // Save all drawings for multi-page support
                    self.container?.saveAllDrawings()
                    self.onDrawingChanged(canvasView.drawing)
                }
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            updatePauseDetectorState()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
            pauseDetector.recordToolEnded()
        }

        private func updateUndoRedoState(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.onUndoStateChanged(canvasView.undoManager?.canUndo ?? false)
                self?.onRedoStateChanged(canvasView.undoManager?.canRedo ?? false)
            }
        }
    }
}

// MARK: - Canvas Container with Zoom and Pan

class CanvasContainerView: UIView {
    let scrollView = UIScrollView()
    let contentView = UIView()  // Container for the stack of pages
    let pagesStackView = UIStackView()  // Vertical stack of page containers

    /// The primary canvas view (first page) - used for delegate assignment
    var canvasView: ReefCanvasView {
        pageContainers.first?.canvasView ?? ReefCanvasView()
    }

    /// All page containers
    private(set) var pageContainers: [PageContainerView] = []

    /// Tracks the currently visible page (0-indexed)
    private var currentVisiblePage: Int = 0

    /// Document ID for persistence
    private var documentID: UUID?

    /// Document structure tracking page modifications
    private var documentStructure: DocumentStructure?

    private var documentURL: URL?
    private var fileType: Note.FileType?
    private var backgroundMode: CanvasBackgroundMode = .normal
    private var backgroundOpacity: CGFloat = 0.15
    private var backgroundSpacing: CGFloat = 48
    private var isDarkMode: Bool = false
    private var questionRegions: DocumentQuestionRegions?

    /// Light gray background for scroll view in light mode (close to white)
    private static let scrollBackgroundLight = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Lighter background for scroll area in dark mode (lighter than the page)
    private static let scrollBackgroundDark = UIColor(red: 18/255, green: 32/255, blue: 52/255, alpha: 1)

    /// Height of the separator line between pages
    static let separatorHeight: CGFloat = 2

    /// Separator views between pages
    private var separatorViews: [UIView] = []

    convenience init(documentID: UUID, documentURL: URL, fileType: Note.FileType, backgroundMode: CanvasBackgroundMode = .normal, backgroundOpacity: CGFloat = 0.15, backgroundSpacing: CGFloat = 48, isDarkMode: Bool = false, questionRegions: DocumentQuestionRegions? = nil) {
        self.init(frame: .zero)
        self.documentID = documentID
        self.documentURL = documentURL
        self.fileType = fileType
        self.backgroundMode = backgroundMode
        self.backgroundOpacity = backgroundOpacity
        self.backgroundSpacing = backgroundSpacing
        self.isDarkMode = isDarkMode
        self.questionRegions = questionRegions
        loadDocument()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = Self.scrollBackgroundLight
        addSubview(scrollView)

        // Configure content view (holds the stack)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

        // Configure pages stack view
        pagesStackView.translatesAutoresizingMaskIntoConstraints = false
        pagesStackView.axis = .vertical
        pagesStackView.alignment = .center
        pagesStackView.distribution = .fill
        pagesStackView.spacing = 0
        contentView.addSubview(pagesStackView)

        // Force light interface style to prevent PencilKit from inverting colors
        self.overrideUserInterfaceStyle = .light

        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            pagesStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pagesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pagesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pagesStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func updateDarkMode(_ newDarkMode: Bool) {
        guard newDarkMode != isDarkMode else { return }
        isDarkMode = newDarkMode

        // Update scroll background and separators
        let newScrollBg = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        UIView.animate(withDuration: 0.3) {
            self.scrollView.backgroundColor = newScrollBg
            // Update separator colors to match background
            for separator in self.separatorViews {
                separator.backgroundColor = newScrollBg
            }
        }

        // Update all page containers
        for container in pageContainers {
            container.updateDarkMode(newDarkMode)
        }

        // Reload document to re-render pages with new theme
        reloadDocument()
    }

    func updateBackgroundMode(_ newMode: CanvasBackgroundMode) {
        guard newMode != backgroundMode else { return }
        backgroundMode = newMode
        for container in pageContainers {
            container.backgroundPatternView.mode = newMode
        }
    }

    func updateBackgroundOpacity(_ newOpacity: CGFloat) {
        guard newOpacity != backgroundOpacity else { return }
        backgroundOpacity = newOpacity
        for container in pageContainers {
            container.backgroundPatternView.opacity = newOpacity
        }
    }

    func updateBackgroundSpacing(_ newSpacing: CGFloat) {
        guard newSpacing != backgroundSpacing else { return }
        backgroundSpacing = newSpacing
        for container in pageContainers {
            container.backgroundPatternView.spacing = newSpacing
        }
    }

    // MARK: - Page Operations

    /// Returns the index of the currently visible page (0-indexed)
    var currentPage: Int {
        return currentVisiblePage
    }

    /// Adds a blank page after the currently visible page
    func addPageAfterCurrent() {
        let insertIndex = currentVisiblePage + 1
        insertBlankPage(at: insertIndex)

        // Update document structure
        documentStructure?.pages.insert(
            DocumentStructure.Page(type: .blank, originalIndex: nil),
            at: insertIndex
        )
        saveDocumentState()

        print("Added blank page after page \(currentVisiblePage + 1), now at index \(insertIndex + 1)")
    }

    /// Adds a blank page at the end of the document
    func addPageToEnd() {
        let insertIndex = pageContainers.count
        insertBlankPage(at: insertIndex)

        // Update document structure
        documentStructure?.pages.append(
            DocumentStructure.Page(type: .blank, originalIndex: nil)
        )
        saveDocumentState()

        print("Added blank page at end, now page \(insertIndex + 1)")
    }

    /// Deletes the currently visible page
    /// Returns false if this is the only page (cannot delete)
    @discardableResult
    func deleteCurrentPage() -> Bool {
        guard pageContainers.count > 1 else {
            print("Cannot delete the only page in the document")
            return false
        }

        let deleteIndex = currentVisiblePage
        deletePage(at: deleteIndex)

        // Update document structure
        documentStructure?.pages.remove(at: deleteIndex)
        saveDocumentState()

        print("Deleted page \(deleteIndex + 1)")
        return true
    }

    /// Clears the drawing on the currently visible page
    func clearCurrentPage() {
        guard currentVisiblePage < pageContainers.count else { return }
        let container = pageContainers[currentVisiblePage]
        container.canvasView.drawing = PKDrawing()
        saveAllDrawings()
        print("Cleared drawing on page \(currentVisiblePage + 1)")
    }

    /// Saves all drawings for all pages
    func saveAllDrawings() {
        guard let documentID = documentID else { return }
        let drawings = pageContainers.map { $0.canvasView.drawing }
        try? DrawingStorageService.shared.saveAllDrawings(drawings, for: documentID)
    }

    /// Saves document structure and all drawings
    private func saveDocumentState() {
        guard let documentID = documentID else { return }

        // Save structure
        if let structure = documentStructure {
            try? DrawingStorageService.shared.saveDocumentStructure(structure, for: documentID)
        }

        // Save all drawings
        saveAllDrawings()
    }

    /// Loads drawings for all pages from storage
    func loadAllDrawings() {
        guard let documentID = documentID else { return }
        let drawings = DrawingStorageService.shared.loadAllDrawings(for: documentID, pageCount: pageContainers.count)
        for (index, drawing) in drawings.enumerated() where index < pageContainers.count {
            pageContainers[index].canvasView.drawing = drawing
        }
    }

    /// Creates a blank page image matching existing page dimensions
    private func createBlankPageImage() -> UIImage {
        return createBlankPageImage(referenceImages: [])
    }

    /// Inserts a blank page at the specified index
    private func insertBlankPage(at index: Int) {
        let blankImage = createBlankPageImage()
        let separatorColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight

        // Create the new page container
        let newContainer = PageContainerView(
            pageImage: blankImage,
            pageIndex: index,
            backgroundMode: backgroundMode,
            backgroundOpacity: backgroundOpacity,
            backgroundSpacing: backgroundSpacing,
            isDarkMode: isDarkMode
        )

        // Calculate the position in the stack view (accounting for separators)
        // Each page except the last has a separator after it
        // Stack view arrangement: [page0, sep0, page1, sep1, page2, ...]
        let stackIndex: Int
        if index == 0 {
            stackIndex = 0
        } else {
            // Position after the separator of the previous page
            // page at index i is at stack position i + (number of separators before it) = i + i = 2*i
            // But we want to insert after page at (index-1), so after its separator
            stackIndex = index * 2
        }

        // Insert the container
        pageContainers.insert(newContainer, at: index)

        // Add to stack view at correct position
        if stackIndex < pagesStackView.arrangedSubviews.count {
            pagesStackView.insertArrangedSubview(newContainer, at: stackIndex)
        } else {
            pagesStackView.addArrangedSubview(newContainer)
        }

        // Set size constraints
        NSLayoutConstraint.activate([
            newContainer.widthAnchor.constraint(equalToConstant: blankImage.size.width),
            newContainer.heightAnchor.constraint(equalToConstant: blankImage.size.height)
        ])

        // Handle separators
        if pageContainers.count > 1 {
            if index == pageContainers.count - 1 {
                // Added at end - add separator before the new page
                let separator = createSeparator(color: separatorColor)
                separatorViews.append(separator)
                // Insert separator just before the new page in the stack
                let separatorStackIndex = stackIndex
                pagesStackView.insertArrangedSubview(separator, at: separatorStackIndex)
                // Move the page after the separator
                pagesStackView.removeArrangedSubview(newContainer)
                pagesStackView.addArrangedSubview(newContainer)
            } else {
                // Inserted in middle - add separator after the new page
                let separator = createSeparator(color: separatorColor)
                separatorViews.insert(separator, at: index)
                // Insert separator after the new page
                let separatorStackIndex = stackIndex + 1
                if separatorStackIndex < pagesStackView.arrangedSubviews.count {
                    pagesStackView.insertArrangedSubview(separator, at: separatorStackIndex)
                } else {
                    pagesStackView.addArrangedSubview(separator)
                }
            }
        }

        // Update content width if needed
        if blankImage.size.width > (contentWidthConstraint?.constant ?? 0) {
            contentWidthConstraint?.isActive = false
            contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: blankImage.size.width)
            contentWidthConstraint?.isActive = true
        }

        layoutIfNeeded()
    }

    /// Creates a separator view
    private func createSeparator(color: UIColor) -> UIView {
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = color
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight)
        ])
        return separator
    }

    /// Deletes a page at the specified index
    private func deletePage(at index: Int) {
        guard index >= 0 && index < pageContainers.count else { return }
        guard pageContainers.count > 1 else { return }

        // Remove the page container
        let container = pageContainers[index]
        container.removeFromSuperview()
        pageContainers.remove(at: index)

        // Handle separator removal
        if !separatorViews.isEmpty {
            if index == 0 {
                // Deleted first page - remove separator after it (now first separator)
                if !separatorViews.isEmpty {
                    let separator = separatorViews.removeFirst()
                    separator.removeFromSuperview()
                }
            } else if index >= pageContainers.count {
                // Deleted last page - remove separator before it (now last separator)
                if !separatorViews.isEmpty {
                    let separator = separatorViews.removeLast()
                    separator.removeFromSuperview()
                }
            } else {
                // Deleted middle page - remove separator at that index
                if index - 1 < separatorViews.count {
                    let separator = separatorViews.remove(at: index - 1)
                    separator.removeFromSuperview()
                }
            }
        }

        // Update current visible page if needed
        if currentVisiblePage >= pageContainers.count {
            currentVisiblePage = pageContainers.count - 1
        }

        layoutIfNeeded()
    }

    private func reloadDocument() {
        guard let url = documentURL, let fileType = fileType else { return }

        Task { [weak self] in
            guard let self = self else { return }

            switch fileType {
            case .pdf:
                let pageImages = await self.renderPDFPages(url: url)
                await MainActor.run {
                    for (index, container) in self.pageContainers.enumerated() {
                        if index < pageImages.count {
                            UIView.transition(
                                with: container.documentImageView,
                                duration: 0.3,
                                options: .transitionCrossDissolve
                            ) {
                                container.documentImageView.image = pageImages[index]
                            }
                        }
                    }
                }
            case .image:
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let processedImage = self.isDarkMode ? self.applyDarkModeFilter(to: image) : image
                    await MainActor.run {
                        if let container = self.pageContainers.first {
                            UIView.transition(
                                with: container.documentImageView,
                                duration: 0.3,
                                options: .transitionCrossDissolve
                            ) {
                                container.documentImageView.image = processedImage
                            }
                        }
                    }
                }
            case .document:
                break
            }
        }
    }

    private func loadDocument() {
        guard let url = documentURL, let fileType = fileType else { return }

        // Update scroll background based on dark mode
        scrollView.backgroundColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight

        Task { [weak self] in
            guard let self = self else { return }

            // Render original document pages
            var originalImages: [UIImage] = []
            switch fileType {
            case .pdf:
                originalImages = await self.renderPDFPages(url: url)
            case .image:
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let processedImage = self.isDarkMode ? self.applyDarkModeFilter(to: image) : image
                    if let img = processedImage {
                        originalImages = [img]
                    }
                }
            case .document:
                break
            }

            await MainActor.run {
                // Load saved structure or create default
                if let documentID = self.documentID,
                   let savedStructure = DrawingStorageService.shared.loadDocumentStructure(for: documentID) {
                    self.documentStructure = savedStructure
                    self.setupPageContainersFromStructure(originalImages: originalImages, structure: savedStructure)
                } else {
                    // No saved structure - create default from original pages
                    let defaultStructure = DocumentStructure.defaultStructure(pageCount: originalImages.count)
                    self.documentStructure = defaultStructure
                    self.setupPageContainers(with: originalImages)
                }

                // Load drawings for all pages
                self.loadAllDrawings()
            }
        }
    }

    /// Sets up page containers based on saved document structure
    private func setupPageContainersFromStructure(originalImages: [UIImage], structure: DocumentStructure) {
        // Remove existing page containers and separators
        for container in pageContainers {
            container.removeFromSuperview()
        }
        pageContainers.removeAll()

        for separator in separatorViews {
            separator.removeFromSuperview()
        }
        separatorViews.removeAll()

        let separatorColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight

        // Build images array according to structure
        var images: [UIImage] = []
        for page in structure.pages {
            switch page.type {
            case .original:
                if let originalIndex = page.originalIndex, originalIndex < originalImages.count {
                    images.append(originalImages[originalIndex])
                }
            case .blank:
                images.append(createBlankPageImage(referenceImages: originalImages))
            }
        }

        // Create page containers
        // Map structure pages to original page indices for question region lookup
        for (index, image) in images.enumerated() {
            // Determine the original page index for question region lookup
            let structurePage = structure.pages[index]
            let regionPageIndex: Int
            if structurePage.type == .original, let origIdx = structurePage.originalIndex {
                regionPageIndex = origIdx
            } else {
                regionPageIndex = -1 // Blank pages have no question regions
            }

            let pageRegions = regionPageIndex >= 0 ? (questionRegions?.regions(forPage: regionPageIndex) ?? []) : []

            let container = PageContainerView(
                pageImage: image,
                pageIndex: index,
                backgroundMode: backgroundMode,
                backgroundOpacity: backgroundOpacity,
                backgroundSpacing: backgroundSpacing,
                isDarkMode: isDarkMode,
                questionRegions: pageRegions
            )

            pageContainers.append(container)
            pagesStackView.addArrangedSubview(container)

            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: image.size.width),
                container.heightAnchor.constraint(equalToConstant: image.size.height)
            ])

            // Add separator after each page except the last one
            if index < images.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = separatorColor
                separatorViews.append(separator)
                pagesStackView.addArrangedSubview(separator)

                NSLayoutConstraint.activate([
                    separator.widthAnchor.constraint(equalTo: pagesStackView.widthAnchor),
                    separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight)
                ])
            }
        }

        // Update content view width
        if let maxWidth = images.map({ $0.size.width }).max() {
            contentWidthConstraint?.isActive = false
            contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: maxWidth)
            contentWidthConstraint?.isActive = true
        }

        layoutIfNeeded()
    }

    /// Creates a blank page image, using reference images for size if available
    private func createBlankPageImage(referenceImages: [UIImage] = []) -> UIImage {
        let pageSize: CGSize
        if let firstImage = referenceImages.first {
            pageSize = firstImage.size
        } else if let firstContainer = pageContainers.first,
                  let existingImage = firstContainer.documentImageView.image {
            pageSize = existingImage.size
        } else {
            // Default to US Letter size at 2x scale
            let scale: CGFloat = 2.0
            pageSize = CGSize(width: 612 * scale, height: 792 * scale)
        }

        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let blankImage = renderer.image { context in
            let bgColor = isDarkMode ? Self.pageBackgroundDark : UIColor.white
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))
        }

        return blankImage
    }

    private func setupPageContainers(with images: [UIImage]) {
        // Remove existing page containers and separators
        for container in pageContainers {
            container.removeFromSuperview()
        }
        pageContainers.removeAll()

        for separator in separatorViews {
            separator.removeFromSuperview()
        }
        separatorViews.removeAll()

        let separatorColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight

        // Create a page container for each image with separators between them
        for (index, image) in images.enumerated() {
            // Get question regions for this page
            let pageRegions = questionRegions?.regions(forPage: index) ?? []

            let container = PageContainerView(
                pageImage: image,
                pageIndex: index,
                backgroundMode: backgroundMode,
                backgroundOpacity: backgroundOpacity,
                backgroundSpacing: backgroundSpacing,
                isDarkMode: isDarkMode,
                questionRegions: pageRegions
            )

            pageContainers.append(container)
            pagesStackView.addArrangedSubview(container)

            // Set size constraints based on image size
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: image.size.width),
                container.heightAnchor.constraint(equalToConstant: image.size.height)
            ])

            // Add separator after each page except the last one
            if index < images.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = separatorColor
                separatorViews.append(separator)
                pagesStackView.addArrangedSubview(separator)

                // Separator spans full width and has fixed height
                NSLayoutConstraint.activate([
                    separator.widthAnchor.constraint(equalTo: pagesStackView.widthAnchor),
                    separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight)
                ])
            }
        }

        // Update content view width to match the widest page
        if let maxWidth = images.map({ $0.size.width }).max() {
            contentWidthConstraint?.isActive = false
            contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: maxWidth)
            contentWidthConstraint?.isActive = true
        }

        layoutIfNeeded()
    }

    private func renderPDFPages(url: URL) async -> [UIImage] {
        guard let document = PDFDocument(url: url) else { return [] }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return [] }

        let scale: CGFloat = 2.0  // Retina quality
        var images: [UIImage] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            let renderer = UIGraphicsImageRenderer(size: CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            ))

            let pageImage = renderer.image { context in
                // Fill with white background
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

                context.cgContext.translateBy(x: 0, y: pageRect.height * scale)
                context.cgContext.scaleBy(x: scale, y: -scale)

                page.draw(with: .mediaBox, to: context.cgContext)
            }

            // Apply dark mode filter if needed
            if isDarkMode, let darkImage = applyDarkModeFilter(to: pageImage) {
                images.append(darkImage)
            } else {
                images.append(pageImage)
            }
        }

        return images
    }

    /// Applies false color filter to convert light mode PDF to dark mode
    private func applyDarkModeFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = ciImage
        falseColor.color0 = CIColor(red: 1, green: 1, blue: 1)
        falseColor.color1 = CIColor(red: 10/255, green: 22/255, blue: 40/255)

        guard let outputImage = falseColor.outputImage else { return image }

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private var contentWidthConstraint: NSLayoutConstraint?

    override func layoutSubviews() {
        super.layoutSubviews()

        // Center content if smaller than scroll view
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

// MARK: - Question Bounding Box Overlay View

/// Draws bounding boxes around detected questions
class QuestionBoundingBoxView: UIView {
    var regions: [QuestionRegion] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var isDarkMode: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard !regions.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Vibrant Teal for main questions
        let tealBoxColor = UIColor(red: 17/255, green: 157/255, blue: 164/255, alpha: 0.3)
        let tealBorderColor = UIColor(red: 17/255, green: 157/255, blue: 164/255, alpha: 0.8)

        // Green for sub-questions (a, b, c, etc.)
        let greenBoxColor = UIColor(red: 34/255, green: 139/255, blue: 34/255, alpha: 0.3)
        let greenBorderColor = UIColor(red: 34/255, green: 139/255, blue: 34/255, alpha: 0.8)

        context.setLineWidth(2.0)

        for region in regions {
            // Determine if this is a sub-question (contains letter like "1a", "2b", etc.)
            let isSubQuestion = region.questionIdentifier?.contains(where: { $0.isLetter }) ?? false

            let boxColor = isSubQuestion ? greenBoxColor : tealBoxColor
            let borderColor = isSubQuestion ? greenBorderColor : tealBorderColor

            context.setFillColor(boxColor.cgColor)
            context.setStrokeColor(borderColor.cgColor)

            // Convert Vision coordinates (normalized, bottom-left origin)
            // to UIKit coordinates (pixel, top-left origin)
            let box = region.textBoundingBox
            let uiRect = CGRect(
                x: box.origin.x * bounds.width,
                y: (1 - box.origin.y - box.height) * bounds.height,
                width: box.width * bounds.width,
                height: box.height * bounds.height
            )

            // Draw filled rectangle with border
            let path = UIBezierPath(roundedRect: uiRect, cornerRadius: 4)
            context.addPath(path.cgPath)
            context.drawPath(using: .fillStroke)

            // Draw question identifier label if available
            if let identifier = region.questionIdentifier {
                let labelText = "Q\(identifier)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]

                let textSize = labelText.size(withAttributes: attributes)
                let labelPadding: CGFloat = 6
                let labelRect = CGRect(
                    x: uiRect.minX,
                    y: uiRect.minY - textSize.height - labelPadding * 2,
                    width: textSize.width + labelPadding * 2,
                    height: textSize.height + labelPadding
                )

                // Draw label background
                context.setFillColor(borderColor.cgColor)
                let labelPath = UIBezierPath(
                    roundedRect: labelRect,
                    byRoundingCorners: [.topLeft, .topRight],
                    cornerRadii: CGSize(width: 4, height: 4)
                )
                context.addPath(labelPath.cgPath)
                context.fillPath()

                // Draw label text
                let textRect = CGRect(
                    x: labelRect.minX + labelPadding,
                    y: labelRect.minY + labelPadding / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                labelText.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}

// MARK: - Page Container View

/// A container view for a single page with its canvas overlay
class PageContainerView: UIView {
    let documentImageView = UIImageView()
    let backgroundPatternView = CanvasBackgroundPatternView()
    let questionBoundingBoxView = QuestionBoundingBoxView()
    let canvasView = ReefCanvasView()
    let pageIndex: Int

    private var isDarkMode: Bool = false

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    init(pageImage: UIImage, pageIndex: Int, backgroundMode: CanvasBackgroundMode, backgroundOpacity: CGFloat, backgroundSpacing: CGFloat, isDarkMode: Bool, questionRegions: [QuestionRegion] = []) {
        self.pageIndex = pageIndex
        self.isDarkMode = isDarkMode
        super.init(frame: .zero)

        setupViews()
        documentImageView.image = pageImage

        // Configure background pattern
        backgroundPatternView.mode = backgroundMode
        backgroundPatternView.opacity = backgroundOpacity
        backgroundPatternView.spacing = backgroundSpacing
        backgroundPatternView.isDarkMode = isDarkMode

        // Configure question bounding boxes
        questionBoundingBoxView.regions = questionRegions
        questionBoundingBoxView.isDarkMode = isDarkMode

        // Set background colors
        let pageBg: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        backgroundColor = pageBg
        documentImageView.backgroundColor = pageBg

        // Configure shadow
        updateShadow(for: isDarkMode)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        // Document image view
        documentImageView.translatesAutoresizingMaskIntoConstraints = false
        documentImageView.contentMode = .scaleAspectFit
        addSubview(documentImageView)

        // Background pattern view
        backgroundPatternView.translatesAutoresizingMaskIntoConstraints = false
        backgroundPatternView.backgroundColor = .clear
        backgroundPatternView.isOpaque = false
        addSubview(backgroundPatternView)

        // Question bounding box overlay (between background and canvas)
        questionBoundingBoxView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(questionBoundingBoxView)

        // Canvas view
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        addSubview(canvasView)

        NSLayoutConstraint.activate([
            documentImageView.topAnchor.constraint(equalTo: topAnchor),
            documentImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            documentImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            documentImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundPatternView.topAnchor.constraint(equalTo: topAnchor),
            backgroundPatternView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundPatternView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundPatternView.bottomAnchor.constraint(equalTo: bottomAnchor),

            questionBoundingBoxView.topAnchor.constraint(equalTo: topAnchor),
            questionBoundingBoxView.leadingAnchor.constraint(equalTo: leadingAnchor),
            questionBoundingBoxView.trailingAnchor.constraint(equalTo: trailingAnchor),
            questionBoundingBoxView.bottomAnchor.constraint(equalTo: bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func updateDarkMode(_ newDarkMode: Bool) {
        isDarkMode = newDarkMode
        backgroundPatternView.isDarkMode = newDarkMode

        let pageBg: UIColor = isDarkMode ? Self.pageBackgroundDark : .white

        UIView.animate(withDuration: 0.3) {
            self.backgroundColor = pageBg
            self.documentImageView.backgroundColor = pageBg
        }

        updateShadow(for: newDarkMode, animated: true)
    }

    private func updateShadow(for darkMode: Bool, animated: Bool = false) {
        let shadowColor = darkMode ? UIColor(white: 0.4, alpha: 1).cgColor : UIColor.black.cgColor
        let shadowOpacity: Float = darkMode ? 0.3 : 0.25
        let shadowRadius: CGFloat = darkMode ? 16 : 12

        if animated {
            let colorAnim = CABasicAnimation(keyPath: "shadowColor")
            colorAnim.fromValue = layer.shadowColor
            colorAnim.toValue = shadowColor
            colorAnim.duration = 0.3

            let opacityAnim = CABasicAnimation(keyPath: "shadowOpacity")
            opacityAnim.fromValue = layer.shadowOpacity
            opacityAnim.toValue = shadowOpacity
            opacityAnim.duration = 0.3

            let radiusAnim = CABasicAnimation(keyPath: "shadowRadius")
            radiusAnim.fromValue = layer.shadowRadius
            radiusAnim.toValue = shadowRadius
            radiusAnim.duration = 0.3

            layer.add(colorAnim, forKey: "shadowColor")
            layer.add(opacityAnim, forKey: "shadowOpacity")
            layer.add(radiusAnim, forKey: "shadowRadius")
        }

        layer.shadowColor = shadowColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = shadowRadius
    }
}

// MARK: - Canvas Background Pattern View

class CanvasBackgroundPatternView: UIView {
    var mode: CanvasBackgroundMode = .normal {
        didSet {
            setNeedsDisplay()
        }
    }

    var isDarkMode: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }

    var opacity: CGFloat = 0.15 {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Spacing between grid lines/dots/lines in points
    var spacing: CGFloat = 48 {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Pattern color - uses the opacity property
    private var patternColor: UIColor {
        isDarkMode ? UIColor(white: 1.0, alpha: opacity) : UIColor(white: 0.0, alpha: opacity)
    }

    override func draw(_ rect: CGRect) {
        guard mode != .normal else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(patternColor.cgColor)
        context.setFillColor(patternColor.cgColor)

        switch mode {
        case .normal:
            break
        case .grid:
            drawGrid(in: rect, context: context)
        case .dotted:
            drawDots(in: rect, context: context)
        case .lined:
            drawLines(in: rect, context: context)
        }
    }

    private func drawGrid(in rect: CGRect, context: CGContext) {
        context.setLineWidth(0.5)

        // Vertical lines
        var x = spacing
        while x < rect.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }

        // Horizontal lines
        var y = spacing
        while y < rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }

        context.strokePath()
    }

    private func drawDots(in rect: CGRect, context: CGContext) {
        let dotRadius: CGFloat = 1.5

        var x = spacing
        while x < rect.width {
            var y = spacing
            while y < rect.height {
                context.fillEllipse(in: CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
                y += spacing
            }
            x += spacing
        }
    }

    private func drawLines(in rect: CGRect, context: CGContext) {
        context.setLineWidth(0.5)

        var y = spacing
        while y < rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }

        context.strokePath()
    }
}

// MARK: - UIScrollViewDelegate

extension CanvasContainerView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentVisiblePage()
    }

    private func updateCurrentVisiblePage() {
        // Get the visible rect in content coordinates
        let visibleRect = CGRect(
            origin: scrollView.contentOffset,
            size: scrollView.bounds.size
        )

        // Find which page's center is in the visible area
        for (index, container) in pageContainers.enumerated() {
            let pageFrame = container.frame
            let pageCenterY = pageFrame.midY

            // Check if page center is within visible area (accounting for zoom)
            if visibleRect.minY / scrollView.zoomScale <= pageCenterY &&
               pageCenterY <= visibleRect.maxY / scrollView.zoomScale {
                if index != currentVisiblePage {
                    currentVisiblePage = index
                    print("Now viewing page \(index + 1)")
                }
                break
            }
        }
    }
}

#Preview {
    DrawingOverlayView(
        documentID: UUID(),
        documentURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        fileType: .pdf,
        selectedTool: .constant(.pen),
        selectedPenColor: .constant(.black),
        selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
        penWidth: .constant(StrokeWidthRange.penDefault),
        highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
        eraserSize: .constant(StrokeWidthRange.eraserDefault),
        eraserType: .constant(.stroke),
        diagramWidth: .constant(StrokeWidthRange.diagramDefault),
        canvasBackgroundMode: .grid
    )
    .background(Color.gray.opacity(0.2))
}

