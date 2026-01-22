//
//  QuizzesView.swift
//  Reef
//

import SwiftUI
import SwiftData

struct QuizzesView: View {
    let course: Course
    var onGenerateQuiz: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        emptyStateView
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.6))

            VStack(spacing: 8) {
                Text("No quizzes yet")
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Generate your first quiz to start practicing")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onGenerateQuiz()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate Quiz")
                        .font(.quicksand(16, weight: .semiBold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.vibrantTeal)
                .cornerRadius(12)
                .shadow(color: Color.vibrantTeal.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }
}

// MARK: - Quiz Configuration Enums

enum QuizDifficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

enum QuizQuestionType: String, CaseIterable {
    case multipleChoice = "Multiple Choice"
    case fillInBlank = "Fill in the Blank"
    case openEnded = "Open Ended"
}

// MARK: - Quiz Generation View (Placeholder)

struct QuizGenerationView: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    // Form state
    @State private var topic: String = ""
    @State private var difficulty: QuizDifficulty = .medium
    @State private var selectedQuestionTypes: Set<QuizQuestionType> = Set(QuizQuestionType.allCases)
    @State private var additionalNotes: String = ""

    private var canGenerate: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedQuestionTypes.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Form fields
                    topicField

                    difficultySelector

                    questionTypesSelector

                    notesField
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Space for fixed button
            }
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
            .overlay(alignment: .bottom) {
                generateButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color.vibrantTeal)

            Text("Generate Quiz")
                .font(.quicksand(24, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            Text("AI will create questions based on your course materials")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text("Generate Quiz")
                    .font(.quicksand(16, weight: .semiBold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canGenerate ? Color.vibrantTeal : Color.vibrantTeal.opacity(0.5))
            .cornerRadius(12)
        }
        .disabled(!canGenerate)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Topic Field

    private var topicField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            TextField("e.g., Chapter 3: Derivatives, Organic Chemistry reactions...", text: $topic)
                .font(.quicksand(16, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                .padding(12)
                .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.oceanMid.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Difficulty Selector

    private var difficultySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            HStack(spacing: 12) {
                ForEach(QuizDifficulty.allCases, id: \.self) { level in
                    Button {
                        difficulty = level
                    } label: {
                        Text(level.rawValue)
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(difficulty == level ? .white : Color.adaptiveText(for: effectiveColorScheme))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                difficulty == level
                                    ? Color.vibrantTeal
                                    : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Question Types Selector

    private var questionTypesSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question Types")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            FlowLayout(spacing: 12) {
                ForEach(QuizQuestionType.allCases, id: \.self) { type in
                    Button {
                        toggleQuestionType(type)
                    } label: {
                        Text(type.rawValue)
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(selectedQuestionTypes.contains(type) ? .white : Color.adaptiveText(for: effectiveColorScheme))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                selectedQuestionTypes.contains(type)
                                    ? Color.vibrantTeal
                                    : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleQuestionType(_ type: QuizQuestionType) {
        if selectedQuestionTypes.contains(type) {
            // Don't allow deselecting the last one
            if selectedQuestionTypes.count > 1 {
                selectedQuestionTypes.remove(type)
            }
        } else {
            selectedQuestionTypes.insert(type)
        }
    }

    // MARK: - Additional Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Notes")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            TextField("Any specific focus areas or instructions for the AI...", text: $additionalNotes, axis: .vertical)
                .font(.quicksand(16, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                .lineLimit(3...6)
                .padding(12)
                .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.oceanMid.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
