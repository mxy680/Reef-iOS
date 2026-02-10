//
//  AssignmentView.swift
//  Reef
//
//  Paginated view for displaying extracted assignment questions with annotation support
//  Reuses the same DrawingOverlayView as document mode for consistent canvas behavior
//

import SwiftUI
import PDFKit
import PencilKit

// MARK: - Assignment View

struct AssignmentView: View {
    let note: Note
    let currentIndex: Int
    @Binding var selectedTool: CanvasTool
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    @Binding var diagramWidth: CGFloat
    @Binding var diagramAutosnap: Bool
    var canvasBackgroundMode: CanvasBackgroundMode = .normal
    var canvasBackgroundOpacity: CGFloat = 0.15
    var canvasBackgroundSpacing: CGFloat = 48
    var isDarkMode: Bool = false
    var isRulerActive: Bool = false
    var textSize: CGFloat = 16
    var textColor: UIColor = .black
    var onPreviousQuestion: () -> Void = {}
    var onNextQuestion: () -> Void = {}
    var onCanvasReady: (CanvasContainerView) -> Void = { _ in }
    var onPauseDetected: ((PauseContext) -> Void)? = nil
    var onUndoStateChanged: (Bool) -> Void = { _ in }
    var onRedoStateChanged: (Bool) -> Void = { _ in }

    private var questions: [ExtractedQuestion] {
        note.extractedQuestions
    }

    private var currentQuestion: ExtractedQuestion? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    /// Returns the file URL for the current question's PDF
    private var questionFileURL: URL? {
        guard let question = currentQuestion else { return nil }
        return FileStorageService.shared.getQuestionFileURL(
            questionSetID: note.id,
            fileName: question.pdfFileName
        )
    }

    /// Returns a unique document ID for the current question (for drawing storage)
    /// We use a deterministic UUID based on note ID and question index
    private var questionDocumentID: UUID {
        // Create a deterministic UUID by combining note ID with question index
        // This ensures each question has its own drawing storage
        let combinedString = "\(note.id.uuidString)-question-\(currentIndex)"
        return UUID(uuidString: combinedString.md5UUID) ?? UUID()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let url = questionFileURL {
                    // Reuse the same DrawingOverlayView as document mode
                    // Use .id() to force view recreation when question changes
                    DrawingOverlayView(
                        documentID: questionDocumentID,
                        documentURL: url,
                        fileType: .pdf,
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
                        isDarkMode: isDarkMode,
                        isRulerActive: isRulerActive,
                        textSize: textSize,
                        textColor: textColor,
                        questionContext: currentQuestion.map { q in
                            StrokeStreamManager.QuestionContext(
                                questionIndex: currentIndex,
                                questionNumber: q.questionNumber,
                                regionData: q.regionData
                            )
                        },
                        onCanvasReady: onCanvasReady,
                        onUndoStateChanged: onUndoStateChanged,
                        onRedoStateChanged: onRedoStateChanged,
                        onPauseDetected: onPauseDetected,
                        onSwipeLeft: onNextQuestion,
                        onSwipeRight: onPreviousQuestion
                    )
                    .id(currentIndex) // Force new view instance for each question
                } else {
                    // No question available - show placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Question not found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isDarkMode ? Color.warmDark : Color.blushWhite)
                }
            }
        }
    }
}

// MARK: - String Extension for Deterministic UUID

extension String {
    /// Creates a deterministic UUID-like string from this string
    /// Used to generate consistent document IDs for question drawings
    var md5UUID: String {
        // Simple hash-based approach to create a valid UUID string format
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Create a second hash for more bits
        var hash2: UInt64 = 0
        for char in self.utf8.reversed() {
            hash2 = ((hash2 << 5) &+ hash2) &+ UInt64(char)
        }

        // Format as UUID string (8-4-4-4-12)
        let hex1 = String(format: "%08X", UInt32(truncatingIfNeeded: hash))
        let hex2 = String(format: "%04X", UInt16(truncatingIfNeeded: hash >> 32))
        let hex3 = String(format: "%04X", UInt16(truncatingIfNeeded: hash >> 48))
        let hex4 = String(format: "%04X", UInt16(truncatingIfNeeded: hash2))
        let hex5 = String(format: "%012X", UInt64(truncatingIfNeeded: hash2 >> 16) & 0xFFFFFFFFFFFF)

        return "\(hex1)-\(hex2)-\(hex3)-\(hex4)-\(hex5)"
    }
}
