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
    var isDarkMode: Bool = false
    var recognitionEnabled: Bool = false
    var pauseSensitivity: Double = 0.5
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }
    var onRecognitionResult: (RecognitionResult) -> Void = { _ in }

    func makeUIView(context: Context) -> CanvasContainerView {
        let container = CanvasContainerView(documentURL: documentURL, fileType: fileType, backgroundMode: canvasBackgroundMode, isDarkMode: isDarkMode)
        container.canvasView.delegate = context.coordinator
        context.coordinator.container = container
        context.coordinator.onUndoStateChanged = onUndoStateChanged
        context.coordinator.onRedoStateChanged = onRedoStateChanged
        context.coordinator.onRecognitionResult = onRecognitionResult
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
        print("[ShapeSnap] updateUIView called with selectedTool=\(selectedTool)")
        context.coordinator.currentTool = selectedTool
        context.coordinator.currentPenColor = UIColor(selectedPenColor)
        context.coordinator.currentPenWidth = penWidth
        updateTool(container.canvasView)
        container.updateDarkMode(isDarkMode)
        container.updateBackgroundMode(canvasBackgroundMode)

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

        // Recognition state
        var recognitionEnabled: Bool = false
        var pauseSensitivity: Double = 0.5

        // Diagram tool state
        var currentTool: CanvasTool = .pen
        var currentPenColor: UIColor = .black
        var currentPenWidth: CGFloat = 4.0
        private var strokeCountBeforeDrawing: Int = 0

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Record stroke count before drawing
            strokeCountBeforeDrawing = canvasView.drawing.strokes.count
            print("[ShapeSnap] Tool began. currentTool=\(currentTool), strokeCount=\(strokeCountBeforeDrawing)")
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

// MARK: - Shape Detector

enum ShapeDetector {
    enum DetectedShape {
        case line(start: CGPoint, end: CGPoint)
        case rectangle(CGRect)
    }

    /// Minimum line length in points
    private static let minLineLength: CGFloat = 20

    /// Maximum perpendicular deviation as percentage of line length (15% is fairly lenient)
    private static let lineDeviationThreshold: CGFloat = 0.15

    /// Threshold for stroke closure (as percentage of bounding diagonal)
    private static let closureThreshold: CGFloat = 0.40

    /// Minimum angle change to detect a corner (in radians, ~30°)
    private static let cornerAngleThreshold: CGFloat = .pi / 6

    /// Main entry point - detects shape and returns snapped stroke if recognized
    static func detect(_ stroke: PKStroke, color: UIColor, width: CGFloat) -> PKStroke? {
        let points = stroke.path.map { $0.location }
        guard points.count >= 3 else { return nil }

        // Try line detection first (simpler shape)
        if let shape = detectLine(points: points) {
            switch shape {
            case .line(let start, let end):
                return StrokeBuilder.createStroke(points: [start, end], color: color, width: width)
            default:
                break
            }
        }

        // Try rectangle detection
        if let shape = detectRectangle(points: points) {
            switch shape {
            case .rectangle(let rect):
                // Generate points along each edge to prevent spline smoothing
                let rectanglePoints = generateRectanglePoints(rect: rect, pointsPerEdge: 10)
                return StrokeBuilder.createStroke(points: rectanglePoints, color: color, width: width)
            default:
                break
            }
        }

        return nil
    }

    /// Detects if points form a straight line
    static func detectLine(points: [CGPoint]) -> DetectedShape? {
        guard let first = points.first, let last = points.last else {
            print("[ShapeSnap] Line: No first/last points")
            return nil
        }

        let lineLength = distance(first, last)
        print("[ShapeSnap] Line: length=\(lineLength), min=\(minLineLength)")
        guard lineLength >= minLineLength else {
            print("[ShapeSnap] Line: Too short")
            return nil
        }

        // Calculate max perpendicular deviation from ideal line
        var maxDeviation: CGFloat = 0
        for point in points {
            let deviation = pointToLineDistance(point: point, lineStart: first, lineEnd: last)
            maxDeviation = max(maxDeviation, deviation)
        }

        let deviationRatio = maxDeviation / lineLength
        print("[ShapeSnap] Line: maxDeviation=\(maxDeviation), ratio=\(deviationRatio), threshold=\(lineDeviationThreshold)")
        guard deviationRatio < lineDeviationThreshold else {
            print("[ShapeSnap] Line: Too much deviation")
            return nil
        }

        print("[ShapeSnap] Line: DETECTED!")
        return .line(start: first, end: last)
    }

    /// Detects if points form a rectangle
    static func detectRectangle(points: [CGPoint]) -> DetectedShape? {
        guard let first = points.first, let last = points.last else { return nil }

        let boundingBox = boundingRect(for: points)

        // Minimum size to avoid snapping tiny marks
        guard boundingBox.width >= 30 && boundingBox.height >= 30 else { return nil }

        let diagonal = distance(
            CGPoint(x: boundingBox.minX, y: boundingBox.minY),
            CGPoint(x: boundingBox.maxX, y: boundingBox.maxY)
        )

        // Check if stroke is closed (endpoints near each other)
        let closedDistance = distance(first, last)
        guard closedDistance < diagonal * closureThreshold else { return nil }

        // Check aspect ratio isn't too extreme (between 1:5 and 5:1)
        let aspectRatio = boundingBox.width / boundingBox.height
        guard aspectRatio > 0.2 && aspectRatio < 5.0 else { return nil }

        // Any closed shape with reasonable proportions snaps to rectangle
        return .rectangle(boundingBox)
    }

    // MARK: - Helper Functions

    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p2.x - p1.x, p2.y - p1.y)
    }

    private static func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let lineLength = distance(lineStart, lineEnd)
        guard lineLength > 0 else { return distance(point, lineStart) }

        // Project point onto line segment
        let t = max(0, min(1, ((point.x - lineStart.x) * (lineEnd.x - lineStart.x) +
                               (point.y - lineStart.y) * (lineEnd.y - lineStart.y)) / (lineLength * lineLength)))

        let projection = CGPoint(
            x: lineStart.x + t * (lineEnd.x - lineStart.x),
            y: lineStart.y + t * (lineEnd.y - lineStart.y)
        )

        return distance(point, projection)
    }

    private static func boundingRect(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Finds corners by detecting direction changes > 60°
    private static func findCorners(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 8 else { return [] }

        var corners: [CGPoint] = []
        let step = max(1, points.count / 30) // Sample at regular intervals

        for i in stride(from: step, to: points.count - step, by: step) {
            let prev = points[i - step]
            let curr = points[i]
            let next = points[i + step]

            let angle1 = atan2(curr.y - prev.y, curr.x - prev.x)
            let angle2 = atan2(next.y - curr.y, next.x - curr.x)
            var angleDiff = abs(angle2 - angle1)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            if angleDiff > cornerAngleThreshold {
                // Ensure this corner is not too close to existing corners
                let tooClose = corners.contains { distance($0, curr) < 20 }
                if !tooClose {
                    corners.append(curr)
                }
            }
        }

        return corners
    }

    /// Validates that opposite sides of a quadrilateral are similar length
    private static func validateRectangleSides(corners: [CGPoint]) -> Bool {
        guard corners.count == 4 else { return false }

        // Sort corners by angle from center to get consistent order
        let center = CGPoint(
            x: corners.map(\.x).reduce(0, +) / 4,
            y: corners.map(\.y).reduce(0, +) / 4
        )

        let sorted = corners.sorted { c1, c2 in
            atan2(c1.y - center.y, c1.x - center.x) < atan2(c2.y - center.y, c2.x - center.x)
        }

        // Check opposite sides
        let side1 = distance(sorted[0], sorted[1])
        let side2 = distance(sorted[1], sorted[2])
        let side3 = distance(sorted[2], sorted[3])
        let side4 = distance(sorted[3], sorted[0])

        // Avoid division by zero
        guard side1 > 0 && side2 > 0 && side3 > 0 && side4 > 0 else { return false }

        let ratio1 = min(side1, side3) / max(side1, side3)
        let ratio2 = min(side2, side4) / max(side2, side4)

        return ratio1 > 0.3 && ratio2 > 0.3
    }

    /// Generates points along each edge of a rectangle to prevent spline smoothing
    private static func generateRectanglePoints(rect: CGRect, pointsPerEdge: Int) -> [CGPoint] {
        var points: [CGPoint] = []

        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),  // Top-left
            CGPoint(x: rect.maxX, y: rect.minY),  // Top-right
            CGPoint(x: rect.maxX, y: rect.maxY),  // Bottom-right
            CGPoint(x: rect.minX, y: rect.maxY),  // Bottom-left
        ]

        // Generate points along each edge
        for i in 0..<4 {
            let start = corners[i]
            let end = corners[(i + 1) % 4]

            for j in 0..<pointsPerEdge {
                let t = CGFloat(j) / CGFloat(pointsPerEdge)
                let point = CGPoint(
                    x: start.x + (end.x - start.x) * t,
                    y: start.y + (end.y - start.y) * t
                )
                points.append(point)
            }
        }

        // Close the rectangle by adding the starting point
        points.append(corners[0])

        return points
    }
}

// MARK: - Stroke Builder

enum StrokeBuilder {
    /// Creates a PKStroke from a list of points using pen ink
    static func createStroke(points: [CGPoint], color: UIColor, width: CGFloat) -> PKStroke {
        var pathPoints: [PKStrokePoint] = []

        for (index, point) in points.enumerated() {
            let strokePoint = PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: width, height: width),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
            pathPoints.append(strokePoint)
        }

        let path = PKStrokePath(controlPoints: pathPoints, creationDate: Date())
        let ink = PKInk(.pen, color: color)
        return PKStroke(ink: ink, path: path)
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
    private var isDarkMode: Bool = false

    /// Light gray background for scroll view in light mode (close to white)
    private static let scrollBackgroundLight = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

    /// Deep Ocean (#0A1628) for document page background in dark mode
    private static let pageBackgroundDark = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Lighter background for scroll area in dark mode (lighter than the page)
    private static let scrollBackgroundDark = UIColor(red: 18/255, green: 32/255, blue: 52/255, alpha: 1)

    convenience init(documentURL: URL, fileType: Note.FileType, backgroundMode: CanvasBackgroundMode = .normal, isDarkMode: Bool = false) {
        self.init(frame: .zero)
        self.documentURL = documentURL
        self.fileType = fileType
        self.backgroundMode = backgroundMode
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

        // Configure background pattern view (behind document)
        backgroundPatternView.translatesAutoresizingMaskIntoConstraints = false
        backgroundPatternView.backgroundColor = .clear
        backgroundPatternView.mode = backgroundMode
        backgroundPatternView.isDarkMode = isDarkMode
        contentView.addSubview(backgroundPatternView)

        // Configure document image view
        documentImageView.translatesAutoresizingMaskIntoConstraints = false
        documentImageView.contentMode = .scaleAspectFit
        documentImageView.backgroundColor = .white
        contentView.addSubview(documentImageView)

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

    /// Spacing between grid lines/dots in points
    private let gridSpacing: CGFloat = 20

    /// Spacing between horizontal lines for lined paper
    private let lineSpacing: CGFloat = 24

    /// Pattern color - subtle gray that doesn't interfere with content
    private var patternColor: UIColor {
        isDarkMode ? UIColor(white: 1.0, alpha: 0.08) : UIColor(white: 0.0, alpha: 0.1)
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
        var x = gridSpacing
        while x < rect.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            x += gridSpacing
        }

        // Horizontal lines
        var y = gridSpacing
        while y < rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += gridSpacing
        }

        context.strokePath()
    }

    private func drawDots(in rect: CGRect, context: CGContext) {
        let dotRadius: CGFloat = 1.5

        var x = gridSpacing
        while x < rect.width {
            var y = gridSpacing
            while y < rect.height {
                context.fillEllipse(in: CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
                y += gridSpacing
            }
            x += gridSpacing
        }
    }

    private func drawLines(in rect: CGRect, context: CGContext) {
        context.setLineWidth(0.5)

        var y = lineSpacing
        while y < rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += lineSpacing
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

