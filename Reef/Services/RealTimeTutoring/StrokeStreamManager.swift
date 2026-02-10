//
//  StrokeStreamManager.swift
//  Reef
//
//  Central orchestrator for the real-time tutoring stroke pipeline.
//  Tracks three stroke categories for full-canvas rendering:
//    - transcribed (gray): sent in previous batches, still on canvas
//    - new (black): added since last batch
//    - erased (red): removed since last batch
//

import Foundation
import PencilKit

/// Orchestrates the stroke capture, classification, batching, and rendering pipeline.
final class StrokeStreamManager {

    // MARK: - Question Context

    /// Optional context about the current question/subquestion being worked on.
    struct QuestionContext {
        let questionIndex: Int
        let questionNumber: Int
        let regionData: ProblemRegionData?
    }

    // MARK: - Configuration

    private let config: BatchTriggerConfig

    // MARK: - Components

    private let batchTrigger: BatchTrigger

    // MARK: - State

    /// Strokes that have been sent in previous batches and are still on the canvas
    private var transcribedStrokes: [StrokeMetadata] = []

    /// Strokes added since the last batch (will render in black)
    private var newStrokes: [StrokeMetadata] = []

    /// Strokes erased since the last batch (will render in red)
    private var erasedStrokes: [StrokeMetadata] = []

    /// Annotation state accumulated across batches
    private var annotationState = AnnotationProcessor.AnnotationState()

    /// Current batch index (monotonically increasing)
    private var batchIndex: Int = 0

    /// Currently active tool (affects classification)
    private var activeTool: CanvasTool = .pen

    /// Current question context (set in assignment mode)
    private var questionContext: QuestionContext?

    /// The current question number, if in assignment mode.
    var currentQuestionNumber: Int? {
        questionContext?.questionNumber
    }

    // MARK: - Callbacks

    /// Called when a batch is ready for API submission
    var onBatchReady: ((BatchPayload) -> Void)?

    // MARK: - Lifecycle

    init(config: BatchTriggerConfig = .default) {
        self.config = config
        self.batchTrigger = BatchTrigger(config: config)
        setupBatchTrigger()
    }

    /// Start the pipeline (begins listening for trigger conditions)
    func start() {
        batchTrigger.start()
    }

    /// Stop the pipeline
    func stop() {
        batchTrigger.stop()
    }

    // MARK: - Public Methods

    /// Record a new stroke from PencilKit.
    /// - Parameters:
    ///   - stroke: The completed PKStroke
    ///   - pageIndex: Which page container the stroke was on
    func recordStroke(_ stroke: PKStroke, pageIndex: Int?) {
        let (label, features) = StrokeClassifier.classify(stroke: stroke, activeTool: activeTool)

        let points = StrokePointExtractor.extractOnCurvePoints(from: stroke)
        let startPoint = points.first ?? .zero
        let endPoint = points.last ?? .zero

        let metadata = StrokeMetadata(
            stroke: stroke,
            timestamp: Date(),
            pageIndex: pageIndex,
            label: label,
            features: features,
            startPoint: startPoint,
            endPoint: endPoint,
            fingerprint: StrokeFingerprint(stroke: stroke)
        )

        newStrokes.append(metadata)
        batchTrigger.recordActivity()
    }

    /// Record that strokes were erased from the canvas.
    /// Matches removed strokes against transcribed + new strokes by fingerprint,
    /// moves matches to the erased array for red rendering.
    func recordErasure(removedStrokes: [PKStroke]) {
        for removed in removedStrokes {
            let removedFP = StrokeFingerprint(stroke: removed)

            // Check transcribed strokes first
            if let idx = transcribedStrokes.firstIndex(where: { $0.fingerprint == removedFP }) {
                let meta = transcribedStrokes.remove(at: idx)
                erasedStrokes.append(meta)
                continue
            }

            // Check new strokes (erasing something drawn since last batch)
            if let idx = newStrokes.firstIndex(where: { $0.fingerprint == removedFP }) {
                // Erasing a not-yet-sent stroke — just remove it, no need to render in red
                newStrokes.remove(at: idx)
                continue
            }
        }
        batchTrigger.recordActivity()
    }

    /// Update the active tool (affects classification behavior).
    func updateTool(_ tool: CanvasTool) {
        activeTool = tool
    }

    /// Update the current question context (for subquestion logging in assignment mode).
    func updateQuestionContext(_ context: QuestionContext?) {
        questionContext = context
    }

    /// Reset all state (e.g., when switching documents).
    func reset() {
        transcribedStrokes.removeAll()
        newStrokes.removeAll()
        erasedStrokes.removeAll()
        annotationState = AnnotationProcessor.AnnotationState()
        batchIndex = 0
        batchTrigger.reset()
    }

    // MARK: - Private

    private func setupBatchTrigger() {
        batchTrigger.onBatchReady = { [weak self] in
            self?.processBatch()
        }
    }

    private func processBatch() {
        guard !newStrokes.isEmpty || !erasedStrokes.isEmpty else { return }

        // Snapshot current state
        let batchNewStrokes = newStrokes
        let batchErasedStrokes = erasedStrokes
        batchTrigger.recordBatchSent()

        // Separate content vs annotation strokes from new strokes
        let contentMeta = batchNewStrokes.filter { !$0.label.isAnnotation }
        let annotationMeta = batchNewStrokes.filter { $0.label.isAnnotation }

        // Process annotations
        if !annotationMeta.isEmpty {
            AnnotationProcessor.process(annotations: annotationMeta, state: &annotationState)
        }

        // Render full canvas with three colors
        let transcribedPKStrokes = transcribedStrokes.map { $0.stroke }
        let newPKStrokes = contentMeta.map { $0.stroke }
        let erasedPKStrokes = batchErasedStrokes.map { $0.stroke }

        let renderResult = BatchRenderer.render(
            transcribedStrokes: transcribedPKStrokes,
            newStrokes: newPKStrokes,
            erasedStrokes: erasedPKStrokes
        )

        // Determine primary page index (most common page among new strokes)
        let allBatchStrokes = batchNewStrokes
        let pageIndices = allBatchStrokes.compactMap { $0.pageIndex }
        let primaryPage: Int?
        if !pageIndices.isEmpty {
            let counts = Dictionary(grouping: pageIndices, by: { $0 }).mapValues { $0.count }
            primaryPage = counts.max(by: { $0.value < $1.value })?.key
        } else {
            primaryPage = nil
        }

        // Resolve subquestion from stroke positions (if in assignment mode)
        var subquestionLabel: String? = nil
        if let qCtx = questionContext, let lastStroke = allBatchStrokes.last {
            let pdfY = CoordinateMapper.canvasToPDFY(lastStroke.endPoint.y)
            let page = lastStroke.pageIndex ?? 0
            if let resolved = RegionResolver.resolve(pdfY: pdfY, page: page, regionData: qCtx.regionData) {
                subquestionLabel = resolved.label
            }
        }

        let payload = BatchPayload(
            batchIndex: batchIndex,
            imageData: renderResult?.imageData,
            contentBounds: renderResult?.contentBounds ?? .zero,
            strokeCount: contentMeta.count,
            annotationCount: annotationMeta.count,
            hasErasures: !batchErasedStrokes.isEmpty,
            strokeMetadata: allBatchStrokes,
            primaryPageIndex: primaryPage,
            timestamp: Date(),
            questionNumber: questionContext?.questionNumber,
            subquestionLabel: subquestionLabel
        )

        batchIndex += 1

        // Move new content strokes to transcribed; clear erased
        transcribedStrokes.append(contentsOf: contentMeta)
        newStrokes.removeAll()
        erasedStrokes.removeAll()

        onBatchReady?(payload)
    }
}
