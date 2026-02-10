//
//  StrokeStreamManager.swift
//  Reef
//
//  Central orchestrator for the real-time tutoring stroke pipeline.
//  Receives strokes → classifies → buffers → triggers → renders → fires callback.
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

    /// Strokes pending in the current batch
    private var pendingStrokes: [StrokeMetadata] = []

    /// Strokes from the last batch (used as gray context for rendering)
    private var previousBatchStrokes: [PKStroke] = []

    /// Annotation state accumulated across batches
    private var annotationState = AnnotationProcessor.AnnotationState()

    /// Current batch index (monotonically increasing)
    private var batchIndex: Int = 0

    /// Currently active tool (affects classification)
    private var activeTool: CanvasTool = .pen

    /// Current question context (set in assignment mode)
    private var questionContext: QuestionContext?

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
            endPoint: endPoint
        )

        pendingStrokes.append(metadata)
        batchTrigger.recordStrokeAdded()
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
        pendingStrokes.removeAll()
        previousBatchStrokes.removeAll()
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
        guard !pendingStrokes.isEmpty else { return }

        // Snapshot and clear pending strokes
        let batchStrokes = pendingStrokes
        pendingStrokes.removeAll()
        batchTrigger.recordBatchSent()

        // Separate content vs annotation strokes
        let contentMeta = batchStrokes.filter { !$0.label.isAnnotation }
        let annotationMeta = batchStrokes.filter { $0.label.isAnnotation }

        // Process annotations
        if !annotationMeta.isEmpty {
            AnnotationProcessor.process(annotations: annotationMeta, state: &annotationState)
        }

        // Render content strokes to image
        let contentStrokes = contentMeta.map { $0.stroke }
        let renderResult = BatchRenderer.render(
            contentStrokes: contentStrokes,
            contextStrokes: previousBatchStrokes
        )

        // Determine primary page index (most common page)
        let pageIndices = batchStrokes.compactMap { $0.pageIndex }
        let primaryPage: Int?
        if !pageIndices.isEmpty {
            let counts = Dictionary(grouping: pageIndices, by: { $0 }).mapValues { $0.count }
            primaryPage = counts.max(by: { $0.value < $1.value })?.key
        } else {
            primaryPage = nil
        }

        // Resolve subquestion from stroke positions (if in assignment mode)
        var subquestionLabel: String? = nil
        if let qCtx = questionContext, let lastStroke = batchStrokes.last {
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
            strokeMetadata: batchStrokes,
            primaryPageIndex: primaryPage,
            timestamp: Date(),
            questionNumber: questionContext?.questionNumber,
            subquestionLabel: subquestionLabel
        )

        batchIndex += 1

        // Store content strokes as context for next batch
        previousBatchStrokes = contentStrokes.suffix(2).map { $0 }

        onBatchReady?(payload)
    }
}
