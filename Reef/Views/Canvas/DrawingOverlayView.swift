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
    var recognitionEnabled: Bool = false
    var pauseSensitivity: Double = 0.5
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }
    var onRecognitionResult: (RecognitionResult) -> Void = { _ in }
    var onDrawingChanged: (PKDrawing) -> Void = { _ in }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentURL: documentURL, fileType: fileType, backgroundMode: canvasBackgroundMode, backgroundOpacity: canvasBackgroundOpacity, backgroundSpacing: canvasBackgroundSpacing, isDarkMode: isDarkMode)
        container.canvasView.delegate = context.coordinator
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged
        context.coordinator.onRecognitionResult = onRecognitionResult
        context.coordinator.onDrawingChanged = onDrawingChanged
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.pauseSensitivity = pauseSensitivity

        // Set initial tool after a brief delay to ensure view is ready
        let initialColor = UIColor(selectedPenColor)
        let width = penWidth
        DispatchQueue.main.async {
            container.canvasView.tool = PKInkingTool(.pen, color: initialColor, width: width)
            self.onCanvasReady(container)
        }

        return container
    }

    func updateUIView(_ container: CanvasContainerView, context: Context) {
        context.coordinator.currentTool = selectedTool
        context.coordinator.currentPenColor = UIColor(selectedPenColor)
        context.coordinator.currentPenWidth = penWidth
        updateTool(container.canvasView)
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
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: penWidth * 4)
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
    let contentView = UIView()  // Container for document + canvas
    let backgroundPatternView = CanvasBackgroundPatternView()
    let documentImageView = UIImageView()
    let canvasView = ReefCanvasView()

    private var documentURL: URL?
    private var fileType: Note.FileType?
    private var backgroundMode: CanvasBackgroundMode = .normal
    private var backgroundOpacity: CGFloat = 0.15
    private var backgroundSpacing: CGFloat = 48
    private var isDarkMode: Bool = false

    /// Light gray background for scroll view in light mode (close to white)
    private static let scrollBackgroundLight = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Lighter background for scroll area in dark mode (lighter than the page)
    private static let scrollBackgroundDark = UIColor(red: 18/255, green: 32/255, blue: 52/255, alpha: 1)

    convenience init(documentURL: URL, fileType: Note.FileType, backgroundMode: CanvasBackgroundMode = .normal, backgroundOpacity: CGFloat = 0.15, backgroundSpacing: CGFloat = 48, isDarkMode: Bool = false) {
        self.init(frame: .zero)
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
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = Self.scrollBackgroundLight  // Updated in loadDocument for dark mode
        addSubview(scrollView)

        // Configure content view (holds both document and canvas)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .white
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.25
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowRadius = 12
        scrollView.addSubview(contentView)

        // Configure document image view
        documentImageView.translatesAutoresizingMaskIntoConstraints = false
        documentImageView.contentMode = .scaleAspectFit
        documentImageView.backgroundColor = .white
        contentView.addSubview(documentImageView)

        // Configure background pattern view (on top of document, below canvas)
        backgroundPatternView.translatesAutoresizingMaskIntoConstraints = false
        backgroundPatternView.backgroundColor = .clear
        backgroundPatternView.isOpaque = false
        backgroundPatternView.mode = backgroundMode
        backgroundPatternView.opacity = backgroundOpacity
        backgroundPatternView.spacing = backgroundSpacing
        backgroundPatternView.isDarkMode = isDarkMode
        contentView.addSubview(backgroundPatternView)

        // Configure canvas view (transparent overlay)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvasView)

        // Force light interface style to prevent PencilKit from inverting colors
        // The app manages dark mode appearance manually via ThemeManager
        self.overrideUserInterfaceStyle = .light

        // Layout constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            // Background pattern fills content view
            backgroundPatternView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundPatternView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundPatternView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundPatternView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Document and canvas fill the content view
            documentImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            documentImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            documentImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            documentImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: contentView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func updateDarkMode(_ newDarkMode: Bool) {
        guard newDarkMode != isDarkMode else { return }
        isDarkMode = newDarkMode
        backgroundPatternView.isDarkMode = newDarkMode
        animateThemeChange()
    }

    func updateBackgroundMode(_ newMode: CanvasBackgroundMode) {
        guard newMode != backgroundMode else { return }
        backgroundMode = newMode
        backgroundPatternView.mode = newMode
    }

    func updateBackgroundOpacity(_ newOpacity: CGFloat) {
        guard newOpacity != backgroundOpacity else { return }
        backgroundOpacity = newOpacity
        backgroundPatternView.opacity = newOpacity
    }

    func updateBackgroundSpacing(_ newSpacing: CGFloat) {
        guard newSpacing != backgroundSpacing else { return }
        backgroundSpacing = newSpacing
        backgroundPatternView.spacing = newSpacing
    }

    private func animateThemeChange() {
        guard let url = documentURL, let fileType = fileType else { return }

        let newScrollBg = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        let newPageBg: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        let newShadowColor = isDarkMode ? UIColor(white: 0.4, alpha: 1).cgColor : UIColor.black.cgColor
        let newShadowOpacity: Float = isDarkMode ? 0.3 : 0.25
        let newShadowRadius: CGFloat = isDarkMode ? 16 : 12

        // Animate background colors
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.scrollView.backgroundColor = newScrollBg
            self.contentView.backgroundColor = newPageBg
            self.documentImageView.backgroundColor = newPageBg
        }

        // Animate shadow changes
        let shadowColorAnim = CABasicAnimation(keyPath: "shadowColor")
        shadowColorAnim.fromValue = contentView.layer.shadowColor
        shadowColorAnim.toValue = newShadowColor
        shadowColorAnim.duration = 0.3

        let shadowOpacityAnim = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacityAnim.fromValue = contentView.layer.shadowOpacity
        shadowOpacityAnim.toValue = newShadowOpacity
        shadowOpacityAnim.duration = 0.3

        let shadowRadiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadiusAnim.fromValue = contentView.layer.shadowRadius
        shadowRadiusAnim.toValue = newShadowRadius
        shadowRadiusAnim.duration = 0.3

        contentView.layer.add(shadowColorAnim, forKey: "shadowColor")
        contentView.layer.add(shadowOpacityAnim, forKey: "shadowOpacity")
        contentView.layer.add(shadowRadiusAnim, forKey: "shadowRadius")

        contentView.layer.shadowColor = newShadowColor
        contentView.layer.shadowOpacity = newShadowOpacity
        contentView.layer.shadowRadius = newShadowRadius

        // Load and crossfade to new document image
        Task { [weak self] in
            let loadedImage: UIImage? = await {
                switch fileType {
                case .pdf:
                    return await self?.renderPDFToImage(url: url)
                case .image:
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                    return nil
                case .document:
                    return nil
                }
            }()

            await MainActor.run { [weak self] in
                guard let self = self, let image = loadedImage else { return }
                UIView.transition(
                    with: self.documentImageView,
                    duration: 0.3,
                    options: .transitionCrossDissolve
                ) {
                    self.documentImageView.image = image
                }
            }
        }
    }

    private func loadDocument() {
        guard let url = documentURL, let fileType = fileType else { return }

        // Update background pattern view with current settings
        backgroundPatternView.mode = backgroundMode
        backgroundPatternView.opacity = backgroundOpacity
        backgroundPatternView.spacing = backgroundSpacing
        backgroundPatternView.isDarkMode = isDarkMode

        // Update backgrounds based on dark mode
        scrollView.backgroundColor = isDarkMode ? Self.scrollBackgroundDark : Self.scrollBackgroundLight
        let pageBgColor: UIColor = isDarkMode ? Self.pageBackgroundDark : .white
        contentView.backgroundColor = pageBgColor
        documentImageView.backgroundColor = pageBgColor

        // Adjust shadow for dark mode
        if isDarkMode {
            contentView.layer.shadowColor = UIColor(white: 0.4, alpha: 1).cgColor
            contentView.layer.shadowOpacity = 0.3
            contentView.layer.shadowRadius = 16
        } else {
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.25
            contentView.layer.shadowRadius = 12
        }

        Task { [weak self] in
            let loadedImage: UIImage? = await {
                switch fileType {
                case .pdf:
                    return await self?.renderPDFToImage(url: url)
                case .image:
                    if let data = try? Data(contentsOf: url) {
                        return UIImage(data: data)
                    }
                    return nil
                case .document:
                    return nil
                }
            }()

            await MainActor.run { [weak self, loadedImage] in
                guard let self = self, let image = loadedImage else { return }
                self.documentImageView.image = image
                self.updateContentSize(for: image.size)
            }
        }
    }

    private func renderPDFToImage(url: URL) async -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0  // Retina quality

        let renderer = UIGraphicsImageRenderer(size: CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        ))

        let normalImage = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            context.cgContext.translateBy(x: 0, y: pageRect.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        // In dark mode, apply false color filter to invert: black text → white, white bg → Deep Ocean
        if isDarkMode {
            return applyDarkModeFilter(to: normalImage)
        }

        return normalImage
    }

    /// Applies false color filter to convert light mode PDF to dark mode
    /// Maps black (text) → white, white (background) → Deep Ocean
    private func applyDarkModeFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = ciImage
        // color0: Black pixels (text) → White for readability
        falseColor.color0 = CIColor(red: 1, green: 1, blue: 1)
        // color1: White pixels (background) → Deep Ocean (#0A1628)
        falseColor.color1 = CIColor(red: 10/255, green: 22/255, blue: 40/255)

        guard let outputImage = falseColor.outputImage else { return image }

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private var contentWidthConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?

    private func updateContentSize(for imageSize: CGSize) {
        // Remove old constraints
        contentWidthConstraint?.isActive = false
        contentHeightConstraint?.isActive = false

        // Set content size based on document
        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: imageSize.width)
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: imageSize.height)

        contentWidthConstraint?.isActive = true
        contentHeightConstraint?.isActive = true

        layoutIfNeeded()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Center content if smaller than scroll view
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
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
}

#Preview {
    DrawingOverlayView(
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

