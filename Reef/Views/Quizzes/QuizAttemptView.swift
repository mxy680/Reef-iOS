//
//  QuizAttemptView.swift
//  Reef
//
//  Paginated view for displaying generated quiz questions with PencilKit annotation.
//  Reuses DrawingOverlayView for consistent canvas behavior (same as AssignmentView).
//

import SwiftUI
import PDFKit
import PencilKit

// MARK: - Quiz Attempt View

struct QuizAttemptView: View {
    let quiz: Quiz
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Question navigation
    @State private var currentQuestionIndex: Int = 0

    // Drawing tool state
    @State private var selectedTool: CanvasTool = .pen
    @State private var selectedPenColor: Color = .black
    @State private var selectedHighlighterColor: Color = .yellow
    @State private var penWidth: CGFloat = 2.0
    @State private var highlighterWidth: CGFloat = 15.0
    @State private var eraserSize: CGFloat = 20.0
    @State private var eraserType: EraserType = .stroke
    @State private var diagramWidth: CGFloat = 2.0
    @State private var diagramAutosnap: Bool = true

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var questions: [QuizQuestionItem] {
        quiz.questions
    }

    private var totalQuestions: Int {
        questions.count
    }

    private var currentQuestion: QuizQuestionItem? {
        guard currentQuestionIndex >= 0 && currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    private var questionFileURL: URL? {
        guard let question = currentQuestion else { return nil }
        return FileStorageService.shared.getQuizQuestionFileURL(
            quizID: quiz.id,
            fileName: question.pdfFileName
        )
    }

    /// Deterministic document ID for drawing storage (same md5UUID pattern as AssignmentView)
    private var questionDocumentID: UUID {
        let combinedString = "\(quiz.id.uuidString)-quiz-\(currentQuestionIndex)"
        return UUID(uuidString: combinedString.md5UUID) ?? UUID()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(for: effectiveColorScheme)
                    .ignoresSafeArea()

                if let url = questionFileURL {
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
                        isDarkMode: themeManager.isDarkMode,
                        onSwipeLeft: {
                            if currentQuestionIndex < totalQuestions - 1 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentQuestionIndex += 1
                                }
                            }
                        },
                        onSwipeRight: {
                            if currentQuestionIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentQuestionIndex -= 1
                                }
                            }
                        }
                    )
                    .id(currentQuestionIndex)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Question not found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(quiz.topic)
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            .lineLimit(1)
                        Text("\(currentQuestionIndex + 1) of \(totalQuestions)")
                            .font(.quicksand(12, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondaryText(for: effectiveColorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            if currentQuestionIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentQuestionIndex -= 1
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(currentQuestionIndex > 0
                                    ? Color.adaptiveText(for: effectiveColorScheme)
                                    : Color.adaptiveSecondaryText(for: effectiveColorScheme).opacity(0.3))
                        }
                        .disabled(currentQuestionIndex == 0)

                        Button {
                            if currentQuestionIndex < totalQuestions - 1 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentQuestionIndex += 1
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(currentQuestionIndex < totalQuestions - 1
                                    ? Color.adaptiveText(for: effectiveColorScheme)
                                    : Color.adaptiveSecondaryText(for: effectiveColorScheme).opacity(0.3))
                        }
                        .disabled(currentQuestionIndex >= totalQuestions - 1)
                    }
                }
            }
            .toolbarBackground(Color.adaptiveBackground(for: effectiveColorScheme), for: .navigationBar)
        }
        .preferredColorScheme(effectiveColorScheme)
    }
}
