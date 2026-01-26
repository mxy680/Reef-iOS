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
        print("[ShapeSnap] updateUIView called with selectedTool=\(selectedTool)")
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

        // Diagram tool state
        var currentTool: CanvasTool = .pen
        var currentPenColor: UIColor = .black
        var currentPenWidth: CGFloat = 4.0
        private var strokeCountBeforeDrawing: Int = 0

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)

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
            // Record stroke count before drawing
            strokeCountBeforeDrawing = canvasView.drawing.strokes.count
            print("[ShapeSnap] Tool began. currentTool=\(currentTool), strokeCount=\(strokeCountBeforeDrawing)")
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            updateUndoRedoState(canvasView)

            print("[ShapeSnap] Tool ended. currentTool=\(currentTool)")

            // Only process for diagram tool
            guard currentTool == .diagram else {
                print("[ShapeSnap] Not diagram tool, skipping")
                return
            }

            let expectedStrokeIndex = strokeCountBeforeDrawing

            // Delay to let PencilKit commit the stroke
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }

                let currentStrokeCount = canvasView.drawing.strokes.count
                print("[ShapeSnap] After delay - Stroke count: before=\(expectedStrokeIndex), after=\(currentStrokeCount)")
                guard currentStrokeCount > expectedStrokeIndex else {
                    print("[ShapeSnap] No new strokes")
                    return
                }

                // Get newly added strokes
                let newStrokeIndices = expectedStrokeIndex..<currentStrokeCount
                var modifiedDrawing = canvasView.drawing
                var strokesModified = false

                // Get grid spacing from container's background pattern view
                let gridSize = self.container?.backgroundPatternView.spacing ?? 0

                // Track which existing strokes to remove (for arrowhead attachment)
                var strokesToRemove: Set<Int> = []

                for strokeIndex in newStrokeIndices {
                    let stroke = modifiedDrawing.strokes[strokeIndex]
                    // Use the stroke's actual width, not recalculated
                    let strokeWidth = stroke.path.first?.size.width ?? (self.currentPenWidth * 4)
                    let pointCount = stroke.path.count
                    print("[ShapeSnap] Processing stroke \(strokeIndex) with \(pointCount) points, width=\(strokeWidth), gridSize=\(gridSize)")

                    // First, check if this is an arrowhead being added to an existing line
                    let existingStrokes = Array(modifiedDrawing.strokes[0..<expectedStrokeIndex])
                    if let result = ShapeDetector.tryAttachArrowhead(
                        arrowheadStroke: stroke,
                        existingStrokes: existingStrokes,
                        color: self.currentPenColor,
                        width: strokeWidth,
                        gridSize: gridSize
                    ) {
                        print("[ShapeSnap] Arrowhead attached to existing line at index \(result.lineStrokeIndex)")
                        modifiedDrawing.strokes[strokeIndex] = result.arrowStroke
                        strokesToRemove.insert(result.lineStrokeIndex)
                        strokesModified = true
                        continue
                    }

                    // Otherwise, try regular shape detection
                    if let snappedStroke = ShapeDetector.detect(stroke, color: self.currentPenColor, width: strokeWidth, gridSize: gridSize) {
                        print("[ShapeSnap] Shape detected! Replacing stroke")
                        modifiedDrawing.strokes[strokeIndex] = snappedStroke
                        strokesModified = true
                    } else {
                        print("[ShapeSnap] No shape detected")
                    }
                }

                // Remove old line strokes that were converted to arrows (in reverse order to preserve indices)
                for indexToRemove in strokesToRemove.sorted().reversed() {
                    modifiedDrawing.strokes.remove(at: indexToRemove)
                    strokesModified = true
                }

                if strokesModified {
                    canvasView.drawing = modifiedDrawing
                    print("[ShapeSnap] Drawing updated with snapped strokes")
                }
            }
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
        case circle(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat)
        case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)
        case arrow(shaftStart: CGPoint, shaftEnd: CGPoint, headAngle: CGFloat)
        case diamond(center: CGPoint, width: CGFloat, height: CGFloat)
    }

    /// Minimum line length in points
    private static let minLineLength: CGFloat = 30

    /// Maximum perpendicular deviation as percentage of line length (12%)
    private static let lineDeviationThreshold: CGFloat = 0.12

    /// Angle threshold for snapping to vertical/horizontal (in radians, ~8°)
    private static let axisSnapThreshold: CGFloat = .pi / 22

    /// Threshold for stroke closure (as percentage of bounding diagonal)
    private static let closureThreshold: CGFloat = 0.20

    /// Minimum angle change to detect a corner (in radians, ~45°)
    private static let cornerAngleThreshold: CGFloat = .pi / 4

    /// Main entry point - detects shape and returns snapped stroke if recognized
    /// - Parameters:
    ///   - stroke: The raw stroke to analyze
    ///   - color: Color for the resulting stroke
    ///   - width: Width for the resulting stroke
    ///   - gridSize: Grid spacing for snapping (0 = no snapping)
    static func detect(_ stroke: PKStroke, color: UIColor, width: CGFloat, gridSize: CGFloat = 0) -> PKStroke? {
        let points = stroke.path.map { $0.location }
        guard points.count >= 3 else { return nil }

        // Try arrow detection first (arrows are lines with arrowheads)
        if let shape = detectArrow(points: points) {
            print("[ShapeSnap] → Arrow detected")
            let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
            return buildStroke(finalShape, color: color, width: width)
        }

        // Try line detection (not closed shapes)
        if let shape = detectLine(points: points) {
            let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
            return buildStroke(finalShape, color: color, width: width)
        }

        // For closed shapes, use circularity to decide between circle and rectangle
        guard isClosedShape(points: points) else { return nil }

        let circularity = calculateCircularity(points: points)
        print("[ShapeSnap] Circularity: \(circularity)")

        // Circularity values (mathematical):
        // - Perfect circle = 1.0
        // - Square ≈ 1.27
        // - Rectangle 2:1 ≈ 1.39
        // - Equilateral triangle ≈ 1.65
        //
        // Hand-drawn shapes have higher values due to imperfections.
        // Use circularity alone - no unreliable corner detection.

        print("[ShapeSnap] Circularity: \(circularity)")

        if circularity < 1.40 {
            // Round shape → Circle
            if let shape = detectCircle(points: points) {
                print("[ShapeSnap] → Circle (circularity \(circularity) < 1.40)")
                let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
                return buildStroke(finalShape, color: color, width: width)
            }
        } else if circularity < 1.70 {
            // Medium angularity → Rectangle or Diamond
            // Check if corners are on axes (diamond) or in quadrants (rectangle)
            if let shape = detectDiamond(points: points) {
                print("[ShapeSnap] → Diamond (circularity \(circularity) in 1.40-1.70)")
                let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
                return buildStroke(finalShape, color: color, width: width)
            }
            if let shape = detectRectangle(points: points) {
                print("[ShapeSnap] → Rectangle (circularity \(circularity) in 1.40-1.70)")
                let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
                return buildStroke(finalShape, color: color, width: width)
            }
        } else {
            // High angularity - could be triangle or messy rectangle
            // Check corner count to disambiguate: 4 corners = rectangle, 3 = triangle
            let allCorners = findCorners(points: points)
            print("[ShapeSnap] High circularity (\(circularity)), found \(allCorners.count) corners")

            if allCorners.count >= 4 {
                // Messy rectangle - prefer rectangle detection
                if let shape = detectRectangle(points: points) {
                    print("[ShapeSnap] → Rectangle (4+ corners detected despite high circularity)")
                    let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
                    return buildStroke(finalShape, color: color, width: width)
                }
            }

            // Fall back to triangle detection
            let triangleCorners = findThreeCorners(points: points)
            if let shape = detectTriangle(points: points, corners: triangleCorners) {
                print("[ShapeSnap] → Triangle (circularity \(circularity) >= 1.70)")
                let finalShape = gridSize > 0 ? snapShapeToGrid(shape, gridSize: gridSize) : shape
                return buildStroke(finalShape, color: color, width: width)
            }
        }

        return nil
    }

    /// Finds the 3 sharpest corners for triangle detection
    private static func findThreeCorners(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 10 else { return [] }

        var candidates: [(point: CGPoint, sharpness: CGFloat)] = []
        let step = max(2, points.count / 40)
        let lookAhead = max(5, points.count / 15)

        for i in stride(from: lookAhead, to: points.count - lookAhead, by: step) {
            let prev = points[i - lookAhead]
            let curr = points[i]
            let next = points[i + lookAhead]

            let angle1 = atan2(curr.y - prev.y, curr.x - prev.x)
            let angle2 = atan2(next.y - curr.y, next.x - curr.x)
            var angleDiff = abs(angle2 - angle1)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            candidates.append((curr, angleDiff))
        }

        // Sort by sharpness (largest angle change first)
        candidates.sort { $0.sharpness > $1.sharpness }

        // Take top 3 that aren't too close together
        var corners: [CGPoint] = []
        let boundingBox = boundingRect(for: points)
        let minDist = min(boundingBox.width, boundingBox.height) * 0.2

        for candidate in candidates {
            let tooClose = corners.contains { distance($0, candidate.point) < minDist }
            if !tooClose {
                corners.append(candidate.point)
                if corners.count == 3 { break }
            }
        }

        return corners
    }

    /// Checks if the stroke forms a closed shape
    private static func isClosedShape(points: [CGPoint]) -> Bool {
        guard let first = points.first, let last = points.last else { return false }
        let boundingBox = boundingRect(for: points)
        let diagonal = distance(
            CGPoint(x: boundingBox.minX, y: boundingBox.minY),
            CGPoint(x: boundingBox.maxX, y: boundingBox.maxY)
        )
        let closedDistance = distance(first, last)
        return closedDistance < diagonal * closureThreshold
    }

    /// Calculates the circularity measure: Perimeter² / (4π × Area)
    /// Perfect circle = 1.0, square ≈ 1.27, rectangles > 1.2
    private static func calculateCircularity(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }

        // Calculate perimeter (sum of distances between consecutive points)
        var perimeter: CGFloat = 0
        for i in 0..<points.count {
            let next = (i + 1) % points.count
            perimeter += distance(points[i], points[next])
        }

        // Calculate area using Shoelace formula
        var area: CGFloat = 0
        for i in 0..<points.count {
            let next = (i + 1) % points.count
            area += points[i].x * points[next].y
            area -= points[next].x * points[i].y
        }
        area = abs(area) / 2

        guard area > 0 else { return 0 }

        // Circularity = P² / (4πA)
        return (perimeter * perimeter) / (4 * .pi * area)
    }

    /// Builds a PKStroke from a detected shape
    private static func buildStroke(_ shape: DetectedShape, color: UIColor, width: CGFloat) -> PKStroke {
        switch shape {
        case .line(let start, let end):
            return StrokeBuilder.createStroke(points: [start, end], color: color, width: width)

        case .rectangle(let rect):
            let rectanglePoints = generateRectanglePoints(rect: rect, pointsPerEdge: 10)
            return StrokeBuilder.createStroke(points: rectanglePoints, color: color, width: width)

        case .circle(let center, let radiusX, let radiusY):
            let ellipsePoints = generateEllipsePoints(center: center, radiusX: radiusX, radiusY: radiusY, pointCount: 48)
            return StrokeBuilder.createStroke(points: ellipsePoints, color: color, width: width)

        case .triangle(let p1, let p2, let p3):
            let trianglePoints = generateTrianglePoints(p1: p1, p2: p2, p3: p3, pointsPerEdge: 10)
            return StrokeBuilder.createStroke(points: trianglePoints, color: color, width: width)

        case .arrow(let shaftStart, let shaftEnd, let headAngle):
            let arrowPoints = generateArrowPoints(shaftStart: shaftStart, shaftEnd: shaftEnd, headLength: 20, headAngle: headAngle)
            return StrokeBuilder.createStroke(points: arrowPoints, color: color, width: width)

        case .diamond(let center, let diamondWidth, let height):
            let diamondPoints = generateDiamondPoints(center: center, width: diamondWidth, height: height, pointsPerEdge: 10)
            return StrokeBuilder.createStroke(points: diamondPoints, color: color, width: width)
        }
    }

    /// Detects if points form a straight line, with axis-alignment for nearly vertical/horizontal lines
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

        // Snap nearly-vertical or nearly-horizontal lines to axis
        let (snappedStart, snappedEnd) = snapLineToAxis(start: first, end: last)

        print("[ShapeSnap] Line: DETECTED!")
        return .line(start: snappedStart, end: snappedEnd)
    }

    /// Snaps a line to vertical or horizontal if it's nearly axis-aligned
    private static func snapLineToAxis(start: CGPoint, end: CGPoint) -> (CGPoint, CGPoint) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let absAngle = abs(angle)

        // Check if nearly vertical (close to ±π/2)
        let verticalDiff = abs(absAngle - .pi / 2)
        if verticalDiff < axisSnapThreshold {
            // Snap to vertical - use average X coordinate
            let avgX = (start.x + end.x) / 2
            print("[ShapeSnap] Line: Snapping to vertical (angle diff: \(verticalDiff * 180 / .pi)°)")
            return (CGPoint(x: avgX, y: start.y), CGPoint(x: avgX, y: end.y))
        }

        // Check if nearly horizontal (close to 0 or ±π)
        let horizontalDiff = min(absAngle, abs(absAngle - .pi))
        if horizontalDiff < axisSnapThreshold {
            // Snap to horizontal - use average Y coordinate
            let avgY = (start.y + end.y) / 2
            print("[ShapeSnap] Line: Snapping to horizontal (angle diff: \(horizontalDiff * 180 / .pi)°)")
            return (CGPoint(x: start.x, y: avgY), CGPoint(x: end.x, y: avgY))
        }

        // Not axis-aligned, return original points
        return (start, end)
    }

    /// Detects if points form a rectangle (closure already verified by caller)
    static func detectRectangle(points: [CGPoint]) -> DetectedShape? {
        let boundingBox = boundingRect(for: points)

        // Minimum size to avoid snapping tiny marks
        guard boundingBox.width >= 50 && boundingBox.height >= 50 else { return nil }

        // Check aspect ratio isn't too extreme (between 1:5 and 5:1)
        let aspectRatio = boundingBox.width / boundingBox.height
        guard aspectRatio > 0.2 && aspectRatio < 5.0 else { return nil }

        return .rectangle(boundingBox)
    }

    /// Detects if points form a circle/ellipse (closure already verified by caller)
    static func detectCircle(points: [CGPoint]) -> DetectedShape? {
        let boundingBox = boundingRect(for: points)

        // Minimum size
        guard boundingBox.width >= 50 && boundingBox.height >= 50 else { return nil }

        let center = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        let radiusX = boundingBox.width / 2
        let radiusY = boundingBox.height / 2

        return .circle(center: center, radiusX: radiusX, radiusY: radiusY)
    }

    /// Detects if points form a triangle (corners pre-computed by caller)
    static func detectTriangle(points: [CGPoint], corners: [CGPoint]) -> DetectedShape? {
        let boundingBox = boundingRect(for: points)

        // Minimum size
        guard boundingBox.width >= 50 && boundingBox.height >= 50 else { return nil }
        guard corners.count == 3 else { return nil }

        // Validate triangle - all sides should be substantial (no degenerate triangles)
        let side1 = distance(corners[0], corners[1])
        let side2 = distance(corners[1], corners[2])
        let side3 = distance(corners[2], corners[0])

        let minSide = min(side1, min(side2, side3))
        let maxSide = max(side1, max(side2, side3))

        guard minSide > maxSide * 0.15 else { return nil }

        return .triangle(p1: corners[0], p2: corners[1], p3: corners[2])
    }

    /// Detects if points form an arrow
    static func detectArrow(points: [CGPoint]) -> DetectedShape? {
        guard points.count >= 10 else { return nil }

        // An arrow is a line with an arrowhead at one end
        // First check if the main body could be a line
        guard let first = points.first, let last = points.last else { return nil }

        let lineLength = distance(first, last)
        guard lineLength >= minLineLength else { return nil }

        // Sample points from the middle portion to check linearity
        let middleStart = points.count / 4
        let middleEnd = points.count * 3 / 4
        let middlePoints = Array(points[middleStart..<middleEnd])

        // Check if middle portion is roughly linear
        var maxMiddleDeviation: CGFloat = 0
        for point in middlePoints {
            let deviation = pointToLineDistance(point: point, lineStart: first, lineEnd: last)
            maxMiddleDeviation = max(maxMiddleDeviation, deviation)
        }

        // Allow more deviation than a pure line since we expect an arrowhead
        let deviationRatio = maxMiddleDeviation / lineLength
        guard deviationRatio < 0.25 else { return nil }

        // Check for arrowhead at either end by looking at how points diverge
        let headCheckCount = min(10, points.count / 4)

        // Check last portion for arrowhead pattern
        let endPoints = Array(points.suffix(headCheckCount))
        if hasArrowhead(points: endPoints, shaftDirection: atan2(last.y - first.y, last.x - first.x)) {
            // Snap shaft to axis if nearly aligned
            let (snappedStart, snappedEnd) = snapLineToAxis(start: first, end: last)
            return .arrow(shaftStart: snappedStart, shaftEnd: snappedEnd, headAngle: .pi / 6)
        }

        // Check first portion for arrowhead pattern (arrow drawn backwards)
        let startPoints = Array(points.prefix(headCheckCount).reversed())
        if hasArrowhead(points: startPoints, shaftDirection: atan2(first.y - last.y, first.x - last.x)) {
            // Snap shaft to axis if nearly aligned
            let (snappedEnd, snappedStart) = snapLineToAxis(start: last, end: first)
            return .arrow(shaftStart: snappedStart, shaftEnd: snappedEnd, headAngle: .pi / 6)
        }

        return nil
    }

    /// Checks if a set of points shows an arrowhead pattern
    private static func hasArrowhead(points: [CGPoint], shaftDirection: CGFloat) -> Bool {
        guard points.count >= 5 else { return false }

        // Look for points that diverge from the shaft direction
        var leftDivergence = 0
        var rightDivergence = 0
        let shaftTip = points.last ?? points[0]

        for i in 0..<(points.count - 1) {
            let point = points[i]
            let toPoint = atan2(point.y - shaftTip.y, point.x - shaftTip.x)
            var angleDiff = toPoint - shaftDirection
            // Normalize to -π to π
            while angleDiff > .pi { angleDiff -= 2 * .pi }
            while angleDiff < -.pi { angleDiff += 2 * .pi }

            let absAngleDiff = abs(angleDiff)

            // Points should diverge at roughly 25-50 degrees from shaft (tighter range)
            if absAngleDiff > .pi / 7 && absAngleDiff < .pi / 3.5 {
                if angleDiff > 0 {
                    leftDivergence += 1
                } else {
                    rightDivergence += 1
                }
            }
        }

        // Need divergence on BOTH sides to confirm arrowhead (not just random wobble)
        return leftDivergence >= 2 && rightDivergence >= 2
    }

    /// Detects if points form a diamond (rotated square)
    /// Key insight: In a diamond, extreme points (top/bottom/left/right) are centered on the perpendicular axis
    /// In a rectangle, extreme points span the full edge
    static func detectDiamond(points: [CGPoint]) -> DetectedShape? {
        let boundingBox = boundingRect(for: points)

        // Minimum size
        guard boundingBox.width >= 50 && boundingBox.height >= 50 else { return nil }

        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        // Find the extreme points
        var topmost = points[0]
        var bottommost = points[0]
        var leftmost = points[0]
        var rightmost = points[0]

        for point in points {
            if point.y < topmost.y { topmost = point }
            if point.y > bottommost.y { bottommost = point }
            if point.x < leftmost.x { leftmost = point }
            if point.x > rightmost.x { rightmost = point }
        }

        // For a diamond, each extreme point should be near the center of the perpendicular axis
        // Tolerance: within 25% of the half-dimension from center
        let xTolerance = boundingBox.width * 0.25
        let yTolerance = boundingBox.height * 0.25

        let topCentered = abs(topmost.x - centerX) < xTolerance
        let bottomCentered = abs(bottommost.x - centerX) < xTolerance
        let leftCentered = abs(leftmost.y - centerY) < yTolerance
        let rightCentered = abs(rightmost.y - centerY) < yTolerance

        let centeredCount = [topCentered, bottomCentered, leftCentered, rightCentered].filter { $0 }.count

        print("[ShapeSnap] Diamond check: top=\(topCentered), bottom=\(bottomCentered), left=\(leftCentered), right=\(rightCentered)")

        // Need at least 3 of 4 extreme points to be centered (allows for imperfect drawing)
        guard centeredCount >= 3 else { return nil }

        return .diamond(center: CGPoint(x: centerX, y: centerY), width: boundingBox.width, height: boundingBox.height)
    }

    // MARK: - Retroactive Arrowhead Detection

    /// Checks if a stroke is an arrowhead shape (V pattern) and returns the tip point if so
    static func detectArrowheadShape(points: [CGPoint]) -> (tip: CGPoint, angle: CGFloat)? {
        guard points.count >= 5 else { return nil }

        let boundingBox = boundingRect(for: points)
        let diagonal = distance(
            CGPoint(x: boundingBox.minX, y: boundingBox.minY),
            CGPoint(x: boundingBox.maxX, y: boundingBox.maxY)
        )

        // Arrowhead should be small (not a full shape)
        guard diagonal < 80 && diagonal > 15 else { return nil }

        // Find the point with the sharpest angle change (the tip)
        var sharpestIndex = 0
        var sharpestAngle: CGFloat = 0
        let step = max(1, points.count / 20)
        let lookAhead = max(2, points.count / 8)

        for i in stride(from: lookAhead, to: points.count - lookAhead, by: step) {
            let prev = points[i - lookAhead]
            let curr = points[i]
            let next = points[i + lookAhead]

            let angle1 = atan2(curr.y - prev.y, curr.x - prev.x)
            let angle2 = atan2(next.y - curr.y, next.x - curr.x)
            var angleDiff = abs(angle2 - angle1)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            if angleDiff > sharpestAngle {
                sharpestAngle = angleDiff
                sharpestIndex = i
            }
        }

        // Need a sharp corner (> 60°) to be an arrowhead
        guard sharpestAngle > .pi / 3 else { return nil }

        let tip = points[sharpestIndex]

        // Calculate the direction the arrowhead points (bisector of the V)
        let beforeTip = points[max(0, sharpestIndex - lookAhead)]
        let afterTip = points[min(points.count - 1, sharpestIndex + lookAhead)]

        let angle1 = atan2(beforeTip.y - tip.y, beforeTip.x - tip.x)
        let angle2 = atan2(afterTip.y - tip.y, afterTip.x - tip.x)

        // Bisector angle (direction arrowhead points)
        var bisector = (angle1 + angle2) / 2
        // The arrowhead points opposite to the bisector of the arms
        bisector += .pi
        if bisector > .pi { bisector -= 2 * .pi }

        return (tip: tip, angle: bisector)
    }

    /// Tries to attach an arrowhead stroke to an existing line stroke
    /// Returns the combined arrow stroke if successful, nil otherwise
    static func tryAttachArrowhead(
        arrowheadStroke: PKStroke,
        existingStrokes: [PKStroke],
        color: UIColor,
        width: CGFloat,
        gridSize: CGFloat = 0
    ) -> (arrowStroke: PKStroke, lineStrokeIndex: Int)? {
        let arrowheadPoints = arrowheadStroke.path.map { $0.location }

        guard let arrowhead = detectArrowheadShape(points: arrowheadPoints) else {
            return nil
        }

        // Look for a line stroke with an endpoint near the arrowhead tip
        let proximityThreshold: CGFloat = 40

        for (index, stroke) in existingStrokes.enumerated() {
            let strokePoints = stroke.path.map { $0.location }

            // Check if this stroke is a line (use existing detection)
            guard let lineShape = detectLine(points: strokePoints),
                  case .line(let start, let end) = lineShape else {
                continue
            }

            // Check if arrowhead tip is near either endpoint
            let distToStart = distance(arrowhead.tip, start)
            let distToEnd = distance(arrowhead.tip, end)

            if distToStart < proximityThreshold {
                // Arrowhead at start - arrow points from end to start
                var shape = DetectedShape.arrow(shaftStart: end, shaftEnd: start, headAngle: .pi / 6)
                if gridSize > 0 {
                    shape = snapShapeToGrid(shape, gridSize: gridSize)
                }
                return (buildStroke(shape, color: color, width: width), index)
            } else if distToEnd < proximityThreshold {
                // Arrowhead at end - arrow points from start to end
                var shape = DetectedShape.arrow(shaftStart: start, shaftEnd: end, headAngle: .pi / 6)
                if gridSize > 0 {
                    shape = snapShapeToGrid(shape, gridSize: gridSize)
                }
                return (buildStroke(shape, color: color, width: width), index)
            }
        }

        return nil
    }

    // MARK: - Grid Snapping

    /// Snaps a value to the nearest grid line
    private static func snapToGrid(_ value: CGFloat, gridSize: CGFloat) -> CGFloat {
        return round(value / gridSize) * gridSize
    }

    /// Snaps a point to the nearest grid intersection
    private static func snapPointToGrid(_ point: CGPoint, gridSize: CGFloat) -> CGPoint {
        return CGPoint(
            x: snapToGrid(point.x, gridSize: gridSize),
            y: snapToGrid(point.y, gridSize: gridSize)
        )
    }

    /// Snaps a detected shape's coordinates to the grid
    private static func snapShapeToGrid(_ shape: DetectedShape, gridSize: CGFloat) -> DetectedShape {
        switch shape {
        case .line(let start, let end):
            return .line(
                start: snapPointToGrid(start, gridSize: gridSize),
                end: snapPointToGrid(end, gridSize: gridSize)
            )

        case .rectangle(let rect):
            let snappedOrigin = snapPointToGrid(CGPoint(x: rect.minX, y: rect.minY), gridSize: gridSize)
            let snappedEnd = snapPointToGrid(CGPoint(x: rect.maxX, y: rect.maxY), gridSize: gridSize)
            return .rectangle(CGRect(
                x: snappedOrigin.x,
                y: snappedOrigin.y,
                width: snappedEnd.x - snappedOrigin.x,
                height: snappedEnd.y - snappedOrigin.y
            ))

        case .circle(let center, let radiusX, let radiusY):
            let snappedCenter = snapPointToGrid(center, gridSize: gridSize)
            // Snap radii to half-grid increments for natural sizing
            let snappedRadiusX = snapToGrid(radiusX, gridSize: gridSize / 2)
            let snappedRadiusY = snapToGrid(radiusY, gridSize: gridSize / 2)
            return .circle(center: snappedCenter, radiusX: snappedRadiusX, radiusY: snappedRadiusY)

        case .triangle(let p1, let p2, let p3):
            return .triangle(
                p1: snapPointToGrid(p1, gridSize: gridSize),
                p2: snapPointToGrid(p2, gridSize: gridSize),
                p3: snapPointToGrid(p3, gridSize: gridSize)
            )

        case .arrow(let start, let end, let headAngle):
            return .arrow(
                shaftStart: snapPointToGrid(start, gridSize: gridSize),
                shaftEnd: snapPointToGrid(end, gridSize: gridSize),
                headAngle: headAngle
            )

        case .diamond(let center, let width, let height):
            let snappedCenter = snapPointToGrid(center, gridSize: gridSize)
            let snappedWidth = snapToGrid(width, gridSize: gridSize)
            let snappedHeight = snapToGrid(height, gridSize: gridSize)
            return .diamond(center: snappedCenter, width: snappedWidth, height: snappedHeight)
        }
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

    /// Finds corners by detecting significant direction changes
    /// Uses adaptive sampling and a lower threshold to catch more corners
    private static func findCorners(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 10 else { return [] }

        var corners: [CGPoint] = []
        var cornerCandidates: [(point: CGPoint, angle: CGFloat)] = []

        // Use smaller step for finer sampling
        let step = max(2, points.count / 50)
        let lookAhead = max(3, points.count / 20)

        for i in stride(from: lookAhead, to: points.count - lookAhead, by: step) {
            let prev = points[i - lookAhead]
            let curr = points[i]
            let next = points[i + lookAhead]

            let angle1 = atan2(curr.y - prev.y, curr.x - prev.x)
            let angle2 = atan2(next.y - curr.y, next.x - curr.x)
            var angleDiff = abs(angle2 - angle1)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            // Lower threshold (30°) to catch softer corners
            if angleDiff > .pi / 6 {
                cornerCandidates.append((curr, angleDiff))
            }
        }

        // Sort by angle magnitude (sharpest corners first)
        cornerCandidates.sort { $0.angle > $1.angle }

        // Take the sharpest corners that aren't too close to each other
        let boundingBox = boundingRect(for: points)
        let minCornerDistance = min(boundingBox.width, boundingBox.height) * 0.15

        for candidate in cornerCandidates {
            let tooClose = corners.contains { distance($0, candidate.point) < minCornerDistance }
            if !tooClose {
                corners.append(candidate.point)
            }
            // Stop after finding enough corners
            if corners.count >= 6 { break }
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

    /// Generates points along an ellipse
    private static func generateEllipsePoints(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, pointCount: Int) -> [CGPoint] {
        var points: [CGPoint] = []

        for i in 0...pointCount {
            let angle = CGFloat(i) / CGFloat(pointCount) * 2 * .pi
            let point = CGPoint(
                x: center.x + radiusX * cos(angle),
                y: center.y + radiusY * sin(angle)
            )
            points.append(point)
        }

        return points
    }

    /// Generates points along a triangle's edges
    private static func generateTrianglePoints(p1: CGPoint, p2: CGPoint, p3: CGPoint, pointsPerEdge: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        let corners = [p1, p2, p3]

        for i in 0..<3 {
            let start = corners[i]
            let end = corners[(i + 1) % 3]

            for j in 0..<pointsPerEdge {
                let t = CGFloat(j) / CGFloat(pointsPerEdge)
                let point = CGPoint(
                    x: start.x + (end.x - start.x) * t,
                    y: start.y + (end.y - start.y) * t
                )
                points.append(point)
            }
        }

        // Close the triangle
        points.append(p1)

        return points
    }

    /// Generates points for an arrow (shaft + head)
    /// Creates a clean symmetrical arrowhead by drawing: left barb → tip → right barb
    private static func generateArrowPoints(shaftStart: CGPoint, shaftEnd: CGPoint, headLength: CGFloat, headAngle: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []

        let shaftAngle = atan2(shaftEnd.y - shaftStart.y, shaftEnd.x - shaftStart.x)

        // Calculate barb points
        let leftAngle = shaftAngle + .pi - headAngle
        let leftPoint = CGPoint(
            x: shaftEnd.x + headLength * cos(leftAngle),
            y: shaftEnd.y + headLength * sin(leftAngle)
        )

        let rightAngle = shaftAngle + .pi + headAngle
        let rightPoint = CGPoint(
            x: shaftEnd.x + headLength * cos(rightAngle),
            y: shaftEnd.y + headLength * sin(rightAngle)
        )

        // Stop the shaft slightly before the tip so arrowhead connects cleanly
        let shaftEndOffset: CGFloat = headLength * 0.3
        let adjustedShaftEnd = CGPoint(
            x: shaftEnd.x - shaftEndOffset * cos(shaftAngle),
            y: shaftEnd.y - shaftEndOffset * sin(shaftAngle)
        )

        // Generate shaft points (from start to adjusted end)
        let shaftPointCount = 10
        for i in 0...shaftPointCount {
            let t = CGFloat(i) / CGFloat(shaftPointCount)
            let point = CGPoint(
                x: shaftStart.x + (adjustedShaftEnd.x - shaftStart.x) * t,
                y: shaftStart.y + (adjustedShaftEnd.y - shaftStart.y) * t
            )
            points.append(point)
        }

        // Draw arrowhead as a continuous V: left barb → tip → right barb
        // First, smoothly transition from shaft end to left barb
        let transitionPoints = 3
        for i in 1...transitionPoints {
            let t = CGFloat(i) / CGFloat(transitionPoints)
            let point = CGPoint(
                x: adjustedShaftEnd.x + (leftPoint.x - adjustedShaftEnd.x) * t,
                y: adjustedShaftEnd.y + (leftPoint.y - adjustedShaftEnd.y) * t
            )
            points.append(point)
        }

        // Left barb to tip
        let barbPoints = 4
        for i in 1...barbPoints {
            let t = CGFloat(i) / CGFloat(barbPoints)
            let point = CGPoint(
                x: leftPoint.x + (shaftEnd.x - leftPoint.x) * t,
                y: leftPoint.y + (shaftEnd.y - leftPoint.y) * t
            )
            points.append(point)
        }

        // Tip to right barb
        for i in 1...barbPoints {
            let t = CGFloat(i) / CGFloat(barbPoints)
            let point = CGPoint(
                x: shaftEnd.x + (rightPoint.x - shaftEnd.x) * t,
                y: shaftEnd.y + (rightPoint.y - shaftEnd.y) * t
            )
            points.append(point)
        }

        return points
    }

    /// Generates points along a diamond's edges
    private static func generateDiamondPoints(center: CGPoint, width: CGFloat, height: CGFloat, pointsPerEdge: Int) -> [CGPoint] {
        var points: [CGPoint] = []

        // Diamond corners: top, right, bottom, left
        let corners = [
            CGPoint(x: center.x, y: center.y - height / 2),  // Top
            CGPoint(x: center.x + width / 2, y: center.y),   // Right
            CGPoint(x: center.x, y: center.y + height / 2),  // Bottom
            CGPoint(x: center.x - width / 2, y: center.y)    // Left
        ]

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

        // Close the diamond
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

