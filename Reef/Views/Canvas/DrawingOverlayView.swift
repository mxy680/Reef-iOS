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
    var canvasBackgroundMode: CanvasBackgroundMode = .normal
    var canvasBackgroundOpacity: CGFloat = 0.15
    var canvasBackgroundSpacing: CGFloat = 48
    var isDarkMode: Bool = false
    var isRulerActive: Bool = false
    var textSize: CGFloat = 16
    var textColor: UIColor = .black
    var recognitionEnabled: Bool = false
    var problemContext: String? = nil
    var documentName: String? = nil
    var questionNumber: Int? = nil
    var regionData: ProblemRegionData? = nil
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }
    var onRecognitionResult: (RecognitionResult) -> Void = { _ in }
    var onDrawingChanged: (PKDrawing) -> Void = { _ in }
    var onSwipeLeft: (() -> Void)? = nil
    var onSwipeRight: (() -> Void)? = nil
    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentID: documentID, documentURL: documentURL, fileType: fileType, backgroundMode: canvasBackgroundMode, backgroundOpacity: canvasBackgroundOpacity, backgroundSpacing: canvasBackgroundSpacing, isDarkMode: isDarkMode)
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged
        context.coordinator.onRecognitionResult = onRecognitionResult
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.problemContext = problemContext
        context.coordinator.regionData = regionData
        container.onSwipeLeft = onSwipeLeft
        container.onSwipeRight = onSwipeRight

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

        // Notify server of session start with question metadata
        AIService.shared.connectStrokeSession(
            sessionId: documentID.uuidString,
            documentName: documentName,
            questionNumber: questionNumber
        )
        AIService.shared.connectSSE(sessionId: documentID.uuidString)

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        context.coordinator.currentTool = selectedTool
        context.coordinator.currentPenColor = UIColor(selectedPenColor)
        context.coordinator.currentPenWidth = penWidth

        // Update tool for all page canvases
        let isEraserTool = selectedTool == .eraser
        for pageContainer in container.pageContainers {
            // Set delegate if not already set (for newly added pages)
            if pageContainer.canvasView.delegate == nil {
                pageContainer.canvasView.delegate = context.coordinator
            }
            updateTool(pageContainer.canvasView)
            pageContainer.canvasView.isRulerActive = isRulerActive
            pageContainer.textBoxContainerView.isTextBoxToolActive = (selectedTool == .textBox)
            pageContainer.textBoxContainerView.currentFontSize = textSize
            pageContainer.textBoxContainerView.currentTextColor = textColor

            // Eraser cursor state
            pageContainer.canvasView.isEraserActive = isEraserTool
            pageContainer.canvasView.isCustomStrokeEraserActive = isEraserTool && eraserType == .stroke
            if isEraserTool {
                pageContainer.canvasView.eraserCursorSize = eraserSize
            }
        }

        container.onSwipeLeft = onSwipeLeft
        container.onSwipeRight = onSwipeRight
        container.updateDarkMode(isDarkMode)
        container.updateBackgroundMode(canvasBackgroundMode)
        container.updateBackgroundOpacity(canvasBackgroundOpacity)
        container.updateBackgroundSpacing(canvasBackgroundSpacing)

        // Keep recognition settings in sync
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.onRecognitionResult = onRecognitionResult

        context.coordinator.problemContext = problemContext
        context.coordinator.regionData = regionData
    }

    private func updateTool(_ canvasView: PKCanvasView) {
        switch selectedTool {
        case .pen, .diagram:
            // Convert SwiftUI Color to UIColor using explicit RGB to avoid color scheme adaptation
            let uiColor = uiColorFromSwiftUIColor(selectedPenColor)
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: penWidth)
            canvasView.isUserInteractionEnabled = true
        case .highlighter:
            let uiColor = UIColor(selectedHighlighterColor).withAlphaComponent(0.3)
            canvasView.tool = PKInkingTool(.marker, color: uiColor, width: highlighterWidth * 3)
            canvasView.isUserInteractionEnabled = true
        case .eraser:
            switch eraserType {
            case .stroke:
                canvasView.tool = PKEraserTool(.vector, width: eraserSize)
            case .bitmap:
                canvasView.tool = PKEraserTool(.bitmap, width: eraserSize)
            }
            canvasView.isUserInteractionEnabled = true
        case .lasso:
            canvasView.tool = PKLassoTool()
            canvasView.isUserInteractionEnabled = true
        case .textBox:
            // Disable PencilKit drawing — text overlay handles input
            canvasView.isUserInteractionEnabled = false
        case .pan:
            // Disable PencilKit drawing — let touches pass through to scroll view
            canvasView.isUserInteractionEnabled = false
        }
    }

    /// Converts SwiftUI Color to UIColor
    /// Since the canvas container has overrideUserInterfaceStyle = .light,
    /// PencilKit won't invert colors and we can use UIColor directly
    private func uiColorFromSwiftUIColor(_ color: Color) -> UIColor {
        return UIColor(color)
    }

    static func dismantleUIView(_ container: CanvasContainerView, coordinator: Coordinator) {
        // Only disconnect if this view's session is still the active one.
        // SwiftUI may call the new view's makeUIView before this dismantleUIView,
        // so blindly disconnecting would kill the new view's socket.
        if AIService.shared.currentSessionId == coordinator.documentID.uuidString {
            AIService.shared.disconnectStrokeSession()
            AIService.shared.disconnectSSE()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(documentID: documentID)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let documentID: UUID

        init(documentID: UUID) {
            self.documentID = documentID
            super.init()
        }

        weak var container: CanvasContainerView?
        var onUndoStateChanged: (Bool) -> Void = { _ in }
        var onRedoStateChanged: (Bool) -> Void = { _ in }
        var onRecognitionResult: (RecognitionResult) -> Void = { _ in }
        var onDrawingChanged: (PKDrawing) -> Void = { _ in }

        // Drawing change debounce
        private var drawingChangeTask: Task<Void, Never>?
        // Stroke send debounce (800ms idle)
        private var strokeSendTask: Task<Void, Never>?

        // Recognition state
        var recognitionEnabled: Bool = false

        // Problem context (stored but no longer triggers pipeline)
        var problemContext: String?

        // Region data for active part detection
        var regionData: ProblemRegionData?
        private var currentActivePart: String? = nil

        // Tool state
        var currentTool: CanvasTool = .pen
        var currentPenColor: UIColor = .black
        var currentPenWidth: CGFloat = 4.0

        // Stroke streaming
        private lazy var strokeSessionId: String = documentID.uuidString
        private var lastSentStrokeCount: [ObjectIdentifier: Int] = [:]

        /// Returns the 1-based page number for a canvas view.
        private func getPageIndex(for canvasView: PKCanvasView) -> Int {
            guard let index = container?.pageContainers.firstIndex(where: { $0.canvasView === canvasView }) else {
                return 1
            }
            return index + 1
        }

        /// Detects which question part the student is writing in based on stroke position.
        /// Returns the part label (e.g. "a", "b") or nil if in the stem or no region data.
        private func detectActivePart(for canvasView: PKCanvasView) -> String? {
            guard let regionData = regionData,
                  !regionData.regions.isEmpty,
                  let lastStroke = canvasView.drawing.strokes.last,
                  let lastPoint = lastStroke.path.last else {
                return nil
            }

            let canvasY = lastPoint.location.y

            // 0-based page index from 1-based getPageIndex
            let pageIndex = getPageIndex(for: canvasView) - 1

            guard pageIndex >= 0, pageIndex < regionData.pageHeights.count else {
                return nil
            }

            // Canvas bounds ≈ PDF points (see plan: Coordinate Mapping Notes)
            let pageHeight = CGFloat(regionData.pageHeights[pageIndex])
            let scaleFactor = canvasView.bounds.height / pageHeight
            let pdfY = canvasY / scaleFactor

            // Find matching region on this page
            for region in regionData.regions {
                if region.page == pageIndex
                    && CGFloat(region.yStart) <= pdfY
                    && pdfY < CGFloat(region.yEnd) {
                    return region.label  // nil for stem
                }
            }

            return nil
        }

        /// Extracts full PKStrokePoint data from new strokes and sends to server.
        /// Sends a clear command to delete all stroke logs for the given canvas's page.
        func clearStrokes(for canvasView: PKCanvasView) {
            let pageNum = getPageIndex(for: canvasView)
            let key = ObjectIdentifier(canvasView)
            lastSentStrokeCount[key] = 0
            AIService.shared.sendClear(sessionId: strokeSessionId, page: pageNum)
        }

        private func strokePointData(from strokes: some Collection<PKStroke>) -> [[[String: Double]]] {
            strokes.map { stroke in
                stroke.path.map { point in
                    [
                        "x": Double(point.location.x),
                        "y": Double(point.location.y),
                        "t": point.timeOffset,
                        "force": Double(point.force),
                        "altitude": Double(point.altitude),
                        "azimuth": Double(point.azimuth)
                    ]
                }
            }
        }

        private func sendNewStrokes(from canvasView: PKCanvasView) {
            let key = ObjectIdentifier(canvasView)
            let allStrokes = canvasView.drawing.strokes
            let previousCount = lastSentStrokeCount[key] ?? 0
            let pageNum = getPageIndex(for: canvasView)
            let contentMode: String? = currentTool == .diagram ? "diagram" : nil

            // Erase detected — send full snapshot of remaining strokes
            // Don't re-detect part (stroke gone); send last known active part
            if allStrokes.count < previousCount {
                let deletedCount = previousCount - allStrokes.count
                lastSentStrokeCount[key] = allStrokes.count
                let strokeData = strokePointData(from: allStrokes)
                AIService.shared.sendStrokes(
                    sessionId: strokeSessionId,
                    page: pageNum,
                    strokes: strokeData,
                    eventType: "erase",
                    deletedCount: deletedCount,
                    partLabel: currentActivePart,
                    contentMode: contentMode
                )
                return
            }

            guard allStrokes.count > previousCount else { return }
            let newStrokes = allStrokes[previousCount...]
            lastSentStrokeCount[key] = allStrokes.count

            // Detect active part from latest stroke position
            if let detected = detectActivePart(for: canvasView) {
                currentActivePart = detected
            }

            let strokeData = strokePointData(from: newStrokes)
            AIService.shared.sendStrokes(
                sessionId: strokeSessionId,
                page: pageNum,
                strokes: strokeData,
                partLabel: currentActivePart,
                contentMode: contentMode
            )
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)

            // Debounced save callback (500ms)
            drawingChangeTask?.cancel()
            drawingChangeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if !Task.isCancelled {
                    self.container?.saveAllDrawings()
                    self.onDrawingChanged(canvasView.drawing)
                }
            }

            // Debounced stroke send (1s idle after last change)
            strokeSendTask?.cancel()
            strokeSendTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    self.sendNewStrokes(from: canvasView)
                }
            }
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
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
    private var originalPageImages: [UIImage] = []

    /// Swipe navigation callbacks (for assignment mode question switching)
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?

    /// Blush White (#F9F5F6) background for scroll view in light mode
    private static let scrollBackgroundLight = UIColor(red: 249/255, green: 245/255, blue: 246/255, alpha: 1)

    /// Warm Dark (#1A1418) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 26/255, green: 20/255, blue: 24/255, alpha: 1)

    /// Warm Dark Card (#251E22) for scroll area in dark mode
    private static let scrollBackgroundDark = UIColor(red: 37/255, green: 30/255, blue: 34/255, alpha: 1)

    /// Height of the separator line between pages
    static let separatorHeight: CGFloat = 2

    /// Separator views between pages
    private var separatorViews: [UIView] = []

    /// Gesture recognizers for undo/redo
    private var undoGestureRecognizer: UITapGestureRecognizer?
    private var redoGestureRecognizer: UITapGestureRecognizer?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    convenience init(documentID: UUID, documentURL: URL, fileType: Note.FileType, backgroundMode: CanvasBackgroundMode = .normal, backgroundOpacity: CGFloat = 0.15, backgroundSpacing: CGFloat = 48, isDarkMode: Bool = false) {
        self.init(frame: .zero)
        self.documentID = documentID
        self.documentURL = documentURL
        self.fileType = fileType
        self.backgroundMode = backgroundMode
        self.backgroundOpacity = backgroundOpacity
        self.backgroundSpacing = backgroundSpacing
        self.isDarkMode = isDarkMode
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

        setupUndoRedoGestures()
        setupSwipeGestures()
    }

    /// Tracks whether the current two-finger pan already fired a navigation action
    private var swipeNavigationFired: Bool = false

    private func setupSwipeGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        // Allow the scroll view's own pan to work simultaneously
        pan.delegate = self
        scrollView.addGestureRecognizer(pan)
    }

    @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            swipeNavigationFired = false
        case .changed:
            guard !swipeNavigationFired else { return }
            let translation = gesture.translation(in: scrollView)
            let threshold: CGFloat = 60
            // Must be primarily horizontal
            guard abs(translation.x) > abs(translation.y) * 1.5 else { return }
            if translation.x < -threshold {
                swipeNavigationFired = true
                onSwipeLeft?()
            } else if translation.x > threshold {
                swipeNavigationFired = true
                onSwipeRight?()
            }
        default:
            break
        }
    }

    private func setupUndoRedoGestures() {
        hapticGenerator.prepare()

        // Two-finger double tap for undo
        let undoGesture = UITapGestureRecognizer(target: self, action: #selector(handleUndoGesture(_:)))
        undoGesture.numberOfTapsRequired = 2
        undoGesture.numberOfTouchesRequired = 2
        addGestureRecognizer(undoGesture)
        undoGestureRecognizer = undoGesture

        // Two-finger triple tap for redo
        let redoGesture = UITapGestureRecognizer(target: self, action: #selector(handleRedoGesture(_:)))
        redoGesture.numberOfTapsRequired = 3
        redoGesture.numberOfTouchesRequired = 2
        addGestureRecognizer(redoGesture)
        redoGestureRecognizer = redoGesture

        // Undo gesture should wait for redo gesture to fail first
        // (prevents undo from firing on the first two taps of a triple tap)
        undoGesture.require(toFail: redoGesture)
    }

    @objc private func handleUndoGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .recognized else { return }
        performUndo()
    }

    @objc private func handleRedoGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .recognized else { return }
        performRedo()
    }

    func performUndo() {
        guard currentVisiblePage < pageContainers.count else { return }
        let canvas = pageContainers[currentVisiblePage].canvasView

        if canvas.undoManager?.canUndo == true {
            canvas.undoManager?.undo()
            hapticGenerator.impactOccurred()
            hapticGenerator.prepare()
        }
    }

    func performRedo() {
        guard currentVisiblePage < pageContainers.count else { return }
        let canvas = pageContainers[currentVisiblePage].canvasView

        if canvas.undoManager?.canRedo == true {
            canvas.undoManager?.redo()
            hapticGenerator.impactOccurred()
            hapticGenerator.prepare()
        }
    }

    func updateDarkMode(_ newDarkMode: Bool) {
        guard newDarkMode != isDarkMode else { return }
        isDarkMode = newDarkMode

        // Pre-render the new page images BEFORE starting any animations
        // This ensures all visual changes happen simultaneously
        Task { [weak self] in
            guard let self = self else { return }
            guard let url = self.documentURL, let fileType = self.fileType else { return }

            // Render new source images in background
            var newImages: [UIImage] = []
            switch fileType {
            case .pdf:
                newImages = await self.renderPDFPages(url: url)
            case .image:
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let processedImage = self.isDarkMode ? self.applyDarkModeFilter(to: image) : image
                    if let img = processedImage {
                        newImages = [img]
                    }
                }
            case .document:
                break
            }

            // Now perform ALL visual updates together on main thread
            await MainActor.run {
                let newScrollBg = self.isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight

                UIView.animate(withDuration: 0.3) {
                    // Update scroll background
                    self.scrollView.backgroundColor = newScrollBg

                    // Update separator colors
                    for separator in self.separatorViews {
                        separator.backgroundColor = newScrollBg
                    }
                }

                // Update stored original images
                self.originalPageImages = newImages

                for (index, container) in self.pageContainers.enumerated() {
                    container.updateDarkMode(newDarkMode)

                    if index < newImages.count {
                        UIView.transition(
                            with: container.documentImageView,
                            duration: 0.3,
                            options: .transitionCrossDissolve
                        ) {
                            container.documentImageView.image = newImages[index]
                        }
                    }
                }
            }
        }
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
    }

    /// Deletes the currently visible page
    /// Returns false if this is the only page (cannot delete)
    @discardableResult
    func deleteCurrentPage() -> Bool {
        guard pageContainers.count > 1 else { return false }

        let deleteIndex = currentVisiblePage
        deletePage(at: deleteIndex)

        // Update document structure
        documentStructure?.pages.remove(at: deleteIndex)
        saveDocumentState()

        return true
    }

    /// Deletes the last page in the document
    /// Returns false if this is the only page (cannot delete)
    @discardableResult
    func deleteLastPage() -> Bool {
        guard pageContainers.count > 1 else { return false }

        let deleteIndex = pageContainers.count - 1
        deletePage(at: deleteIndex)

        documentStructure?.pages.remove(at: deleteIndex)
        saveDocumentState()

        return true
    }

    /// Clears the drawing on the currently visible page
    func clearCurrentPage() {
        guard currentVisiblePage < pageContainers.count else { return }
        let container = pageContainers[currentVisiblePage]
        if let coordinator = container.canvasView.delegate as? DrawingOverlayView.Coordinator {
            coordinator.clearStrokes(for: container.canvasView)
        }
        container.canvasView.drawing = PKDrawing()
        saveAllDrawings()
    }

    // MARK: - PDF Export

    /// Collects export data for all pages, re-rendering document pages in light mode (no dark filter).
    @MainActor
    func exportPageData() async -> [PDFExportService.PageExportData] {
        // Re-render document pages in light mode for export
        var lightImages: [UIImage] = []
        if let url = documentURL, let fileType = fileType {
            switch fileType {
            case .pdf:
                lightImages = await renderPDFPagesForExport(url: url)
            case .image:
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    lightImages = [image]
                }
            case .document:
                break
            }
        }

        guard let structure = documentStructure else {
            // No structure - treat each image as an original page
            return lightImages.enumerated().map { index, image in
                var drawing = index < pageContainers.count ? pageContainers[index].canvasView.drawing : PKDrawing()
                if isDarkMode { drawing = PageContainerView.invertDrawingColors(drawing) }
                let textBoxes = index < pageContainers.count ? pageContainers[index].textBoxContainerView.textBoxes : []
                return PDFExportService.PageExportData(
                    image: image,
                    drawing: drawing,
                    pageSize: image.size,
                    textBoxes: textBoxes
                )
            }
        }

        var exportPages: [PDFExportService.PageExportData] = []
        for (i, page) in structure.pages.enumerated() {
            var drawing = i < pageContainers.count ? pageContainers[i].canvasView.drawing : PKDrawing()
            if isDarkMode { drawing = PageContainerView.invertDrawingColors(drawing) }
            let pageSize = i < pageContainers.count
                ? (pageContainers[i].documentImageView.image?.size ?? CGSize(width: 1224, height: 1584))
                : CGSize(width: 1224, height: 1584)
            let textBoxes = i < pageContainers.count ? pageContainers[i].textBoxContainerView.textBoxes : []

            switch page.type {
            case .original:
                let image: UIImage?
                if let originalIndex = page.originalIndex, originalIndex < lightImages.count {
                    image = lightImages[originalIndex]
                } else {
                    image = nil
                }
                exportPages.append(PDFExportService.PageExportData(image: image, drawing: drawing, pageSize: pageSize, textBoxes: textBoxes))
            case .blank:
                exportPages.append(PDFExportService.PageExportData(image: nil, drawing: drawing, pageSize: pageSize, textBoxes: textBoxes))
            }
        }
        return exportPages
    }

    /// Renders PDF pages in light mode (never applies dark mode filter) for export.
    private func renderPDFPagesForExport(url: URL) async -> [UIImage] {
        guard let document = PDFDocument(url: url) else { return [] }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return [] }

        let renderScale: CGFloat = 2.0
        var images: [UIImage] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            let imageSize = CGSize(
                width: pageRect.width * renderScale,
                height: pageRect.height * renderScale
            )

            // Explicit 1x so image.size in points = pixel dimensions = canvas coordinates
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

            let pageImage = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))

                context.cgContext.translateBy(x: 0, y: pageRect.height * renderScale)
                context.cgContext.scaleBy(x: renderScale, y: -renderScale)

                page.draw(with: .mediaBox, to: context.cgContext)
            }

            // Always light mode - never apply dark mode filter
            images.append(pageImage)
        }

        return images
    }

    /// Saves all drawings and text boxes for all pages (always in light mode colors)
    func saveAllDrawings() {
        guard let documentID = documentID else { return }
        let drawings = pageContainers.map { container -> PKDrawing in
            if isDarkMode {
                // Un-invert colors back to light mode for storage
                return PageContainerView.invertDrawingColors(container.canvasView.drawing)
            }

            return container.canvasView.drawing
        }
        try? DrawingStorageService.shared.saveAllDrawings(drawings, for: documentID)

        // Also save text boxes
        let allTextBoxes = pageContainers.map { $0.textBoxContainerView.textBoxes }
        try? DrawingStorageService.shared.saveAllTextBoxes(allTextBoxes, for: documentID)
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

    /// Loads drawings and text boxes for all pages from storage (inverts drawings if currently in dark mode)
    func loadAllDrawings() {
        guard let documentID = documentID else { return }
        let drawings = DrawingStorageService.shared.loadAllDrawings(for: documentID, pageCount: pageContainers.count)
        for (index, drawing) in drawings.enumerated() where index < pageContainers.count {
            if isDarkMode {
                pageContainers[index].canvasView.drawing = PageContainerView.invertDrawingColors(drawing)
            } else {
                pageContainers[index].canvasView.drawing = drawing
            }
        }

        // Load text boxes
        let allTextBoxes = DrawingStorageService.shared.loadAllTextBoxes(for: documentID, pageCount: pageContainers.count)
        for (index, textBoxes) in allTextBoxes.enumerated() where index < pageContainers.count {
            pageContainers[index].textBoxContainerView.loadTextBoxes(textBoxes)
            pageContainers[index].textBoxContainerView.onTextBoxesChanged = { [weak self] in
                self?.saveAllDrawings()
            }
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
        newContainer.textBoxContainerView.onTextBoxesChanged = { [weak self] in
            self?.saveAllDrawings()
        }

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

        // Set size constraints and store height constraint reference
        let heightConstraint = newContainer.heightAnchor.constraint(equalToConstant: blankImage.size.height)
        newContainer.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            newContainer.widthAnchor.constraint(equalToConstant: blankImage.size.width),
            heightConstraint
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
                // Store original page images for assignment mode cropping
                self.originalPageImages = originalImages

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

                // Load drawings and text boxes for all pages
                self.loadAllDrawings()

                // Center and fit document after layout completes
                DispatchQueue.main.async {
                    self.centerAndFitDocument()
                }
            }
        }
    }

    /// Centers the document and zooms to fit the viewport width
    private func centerAndFitDocument() {
        // Wait for layout to complete
        layoutIfNeeded()

        // Get the content size and viewport size
        let viewportSize = scrollView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        // Get the content size (from the widest page)
        guard let contentWidth = pageContainers.first?.bounds.width, contentWidth > 0 else { return }

        // Calculate zoom scale to fit width with some padding
        let horizontalPadding: CGFloat = 40
        let availableWidth = viewportSize.width - horizontalPadding
        let zoomToFitWidth = availableWidth / contentWidth

        // Clamp to min/max zoom scales
        let targetZoom = min(max(zoomToFitWidth, scrollView.minimumZoomScale), scrollView.maximumZoomScale)

        // Set the zoom scale - this will trigger layoutSubviews which sets content insets for centering
        scrollView.zoomScale = targetZoom

        // Force layout update to recalculate content insets
        setNeedsLayout()
        layoutIfNeeded()

        // Scroll to top with a small padding (content insets handle horizontal centering)
        let topPadding: CGFloat = 20
        scrollView.contentOffset = CGPoint(
            x: -scrollView.contentInset.left,
            y: -scrollView.contentInset.top - topPadding
        )
    }

    /// Fit document width to viewport
    func fitToWidth() {
        centerAndFitDocument()
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
        for (index, image) in images.enumerated() {
            let container = PageContainerView(
                pageImage: image,
                pageIndex: index,
                backgroundMode: backgroundMode,
                backgroundOpacity: backgroundOpacity,
                backgroundSpacing: backgroundSpacing,
                isDarkMode: isDarkMode
            )

            pageContainers.append(container)
            pagesStackView.addArrangedSubview(container)

            // Store height constraint reference for workspace operations
            let heightConstraint = container.heightAnchor.constraint(equalToConstant: image.size.height)
            container.heightConstraint = heightConstraint
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: image.size.width),
                heightConstraint
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
            let container = PageContainerView(
                pageImage: image,
                pageIndex: index,
                backgroundMode: backgroundMode,
                backgroundOpacity: backgroundOpacity,
                backgroundSpacing: backgroundSpacing,
                isDarkMode: isDarkMode
            )

            pageContainers.append(container)
            pagesStackView.addArrangedSubview(container)

            // Set size constraints based on image size and store height constraint reference
            let heightConstraint = container.heightAnchor.constraint(equalToConstant: image.size.height)
            container.heightConstraint = heightConstraint
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: image.size.width),
                heightConstraint
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
        falseColor.color1 = CIColor(red: 26/255, green: 20/255, blue: 24/255)

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

        // Center content if smaller than scroll view, with minimum top padding
        let minTopPadding: CGFloat = 20
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, minTopPadding)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }
}

// MARK: - Page Container View

/// A container view for a single page with its canvas overlay
class PageContainerView: UIView {
    let documentImageView = UIImageView()
    let backgroundPatternView = CanvasBackgroundPatternView()
    let canvasView = ReefCanvasView()
    let textBoxContainerView = TextBoxContainerView()
    let pageIndex: Int

    /// Stored reference to height constraint for workspace operations
    var heightConstraint: NSLayoutConstraint?

    private var isDarkMode: Bool = false

    /// Warm Dark (#1A1418) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 26/255, green: 20/255, blue: 24/255, alpha: 1)

    init(pageImage: UIImage, pageIndex: Int, backgroundMode: CanvasBackgroundMode, backgroundOpacity: CGFloat, backgroundSpacing: CGFloat, isDarkMode: Bool) {
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

        // Set background colors
        let pageBg: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        backgroundColor = pageBg
        documentImageView.backgroundColor = pageBg

        // Configure border
        updateBorder(for: isDarkMode)
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

        // Canvas view
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        #if targetEnvironment(simulator)
        canvasView.drawingPolicy = .anyInput
        #else
        canvasView.drawingPolicy = .pencilOnly
        #endif
        addSubview(canvasView)

        // Text box container view (above canvas)
        textBoxContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textBoxContainerView)

        NSLayoutConstraint.activate([
            documentImageView.topAnchor.constraint(equalTo: topAnchor),
            documentImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            documentImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            documentImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundPatternView.topAnchor.constraint(equalTo: topAnchor),
            backgroundPatternView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundPatternView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundPatternView.bottomAnchor.constraint(equalTo: bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),

            textBoxContainerView.topAnchor.constraint(equalTo: topAnchor),
            textBoxContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textBoxContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textBoxContainerView.bottomAnchor.constraint(equalTo: bottomAnchor)
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

        updateBorder(for: newDarkMode, animated: true)
        invertCanvasDrawingColors()
    }

    /// Inverts stroke colors on this page's canvas for dark/light mode toggle.
    private func invertCanvasDrawingColors() {
        canvasView.drawing = Self.invertDrawingColors(canvasView.drawing)
    }

    /// Returns a new PKDrawing with all stroke colors inverted.
    static func invertDrawingColors(_ drawing: PKDrawing) -> PKDrawing {
        let invertedStrokes = drawing.strokes.map { stroke -> PKStroke in
            var newStroke = stroke
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            stroke.ink.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let invertedColor = UIColor(red: 1 - r, green: 1 - g, blue: 1 - b, alpha: a)
            newStroke.ink = PKInk(stroke.ink.inkType, color: invertedColor)
            return newStroke
        }
        return PKDrawing(strokes: invertedStrokes)
    }

    private func updateBorder(for darkMode: Bool, animated: Bool = false) {
        let borderColor = darkMode
            ? UIColor.white.withAlphaComponent(0.15).cgColor
            : UIColor.black.withAlphaComponent(0.4).cgColor

        if animated {
            let colorAnim = CABasicAnimation(keyPath: "borderColor")
            colorAnim.fromValue = layer.borderColor
            colorAnim.toValue = borderColor
            colorAnim.duration = 0.3
            layer.add(colorAnim, forKey: "borderColor")
        }

        layer.borderWidth = 1.5
        layer.borderColor = borderColor
        layer.shadowOpacity = 0
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
                }
                break
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension CanvasContainerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow the two-finger pan to work alongside the scroll view's pan
        if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer == scrollView.panGestureRecognizer {
            return true
        }
        return false
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
        canvasBackgroundMode: .grid
    )
    .background(Color.gray.opacity(0.2))
}

