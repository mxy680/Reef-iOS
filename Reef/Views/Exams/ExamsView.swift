//
//  ExamsView.swift
//  Reef
//

import SwiftUI
import SwiftData

struct ExamsView: View {
    let course: Course
    var onGenerateExam: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    @Query private var allExams: [ExamAttempt]

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var exams: [ExamAttempt] {
        allExams
            .filter { $0.courseName == course.name }
            .sorted { $0.dateTaken > $1.dateTaken }
    }

    var body: some View {
        Group {
            if exams.isEmpty {
                emptyStateView
            } else {
                examsList
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.6))

            VStack(spacing: 8) {
                Text("No exams yet")
                    .font(.nunito(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Generate your first practice exam to test your knowledge")
                    .font(.nunito(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                onGenerateExam?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate Exam")
                        .font(.nunito(16, weight: .semiBold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.vibrantTeal)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Exams List

    private var examsList: some View {
        List {
            ForEach(exams) { exam in
                ExamListItem(exam: exam)
            }
            .onDelete(perform: deleteExams)
        }
        .listStyle(.plain)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteExams(at offsets: IndexSet) {
        for index in offsets {
            let exam = exams[index]
            modelContext.delete(exam)
        }
    }
}

// MARK: - Exam List Item

struct ExamListItem: View {
    let exam: ExamAttempt
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 24))
                .foregroundColor(statusColor)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(exam.dateTaken.formatted(date: .abbreviated, time: .shortened))
                    .font(.nunito(16, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                if let score = exam.scoreAchieved {
                    HStack(spacing: 8) {
                        Text("\(score)%")
                            .font(.nunito(14, weight: .semiBold))
                            .foregroundColor(statusColor)

                        if let species = exam.speciesUnlocked {
                            Text("• \(species) unlocked")
                                .font(.nunito(12, weight: .regular))
                                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                        } else if exam.passed == false {
                            Text("• Not passed")
                                .font(.nunito(12, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                        }
                    }
                } else {
                    Text("In progress")
                        .font(.nunito(12, weight: .regular))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.4))
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    private var statusIcon: String {
        guard exam.isCompleted else { return "clock" }
        return exam.passed == true ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var statusColor: Color {
        guard exam.isCompleted else { return Color.adaptiveSecondary(for: effectiveColorScheme) }
        return exam.passed == true ? .green : .orange
    }
}

// MARK: - Generate Exam Sheet

struct GenerateExamSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    @State private var selectedTimeLimit = 30
    @State private var selectedPassingScore = 70

    private let timeLimitOptions = [15, 30, 45, 60]
    private let passingScoreOptions = [60, 70, 80, 90]

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(Color.vibrantTeal)

                    Text("Generate Practice Exam")
                        .font(.nunito(24, weight: .bold))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                    Text("AI will create a customized exam based on your course materials")
                        .font(.nunito(14, weight: .regular))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                // Configuration
                VStack(spacing: 20) {
                    // Time Limit
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Limit")
                            .font(.nunito(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        HStack(spacing: 12) {
                            ForEach(timeLimitOptions, id: \.self) { minutes in
                                Button {
                                    selectedTimeLimit = minutes
                                } label: {
                                    Text("\(minutes) min")
                                        .font(.nunito(14, weight: .medium))
                                        .foregroundColor(selectedTimeLimit == minutes ? .white : Color.adaptiveText(for: effectiveColorScheme))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedTimeLimit == minutes
                                                ? Color.vibrantTeal
                                                : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Passing Score
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Passing Score")
                            .font(.nunito(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        HStack(spacing: 12) {
                            ForEach(passingScoreOptions, id: \.self) { score in
                                Button {
                                    selectedPassingScore = score
                                } label: {
                                    Text("\(score)%")
                                        .font(.nunito(14, weight: .medium))
                                        .foregroundColor(selectedPassingScore == score ? .white : Color.adaptiveText(for: effectiveColorScheme))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedPassingScore == score
                                                ? Color.vibrantTeal
                                                : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Generate Button
                Button {
                    generateExam()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Generate Exam")
                            .font(.nunito(16, weight: .semiBold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.vibrantTeal)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.nunito(16, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
    }

    private func generateExam() {
        // Create mock exam with sample questions
        let exam = ExamAttempt(
            courseName: course.name,
            timeLimit: selectedTimeLimit,
            passingScore: selectedPassingScore,
            questions: generateMockQuestions()
        )

        modelContext.insert(exam)
        dismiss()

        // TODO: Navigate to exam taking view
    }

    private func generateMockQuestions() -> [ExamQuestion] {
        // Mock questions for testing
        [
            ExamQuestion(
                questionText: "What is the primary purpose of this course material?",
                questionType: .multipleChoice,
                options: ["To learn fundamentals", "To practice advanced concepts", "To review basics", "To prepare for exams"],
                correctAnswer: "To learn fundamentals",
                topic: "Introduction"
            ),
            ExamQuestion(
                questionText: "The key concept discussed in Chapter 1 is ______.",
                questionType: .fillInBlank,
                correctAnswer: "foundations",
                topic: "Chapter 1"
            ),
            ExamQuestion(
                questionText: "Explain the main theory presented in this course.",
                questionType: .openEnded,
                correctAnswer: "",
                topic: "Theory"
            )
        ]
    }
}
