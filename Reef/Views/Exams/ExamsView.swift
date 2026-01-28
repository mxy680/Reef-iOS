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
                    .font(.quicksand(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Generate your first practice exam to test your knowledge")
                    .font(.quicksand(16, weight: .regular))
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
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                if let score = exam.scoreAchieved {
                    HStack(spacing: 8) {
                        Text("\(score)%")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(statusColor)

                        if let species = exam.speciesUnlocked {
                            Text("• \(species) unlocked")
                                .font(.quicksand(12, weight: .regular))
                                .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                        } else if exam.passed == false {
                            Text("• Not passed")
                                .font(.quicksand(12, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                        }
                    }
                } else {
                    Text("In progress")
                        .font(.quicksand(12, weight: .regular))
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

    @State private var topic: String = ""
    @State private var selectedTimeLimit = 30
    @State private var selectedPassingScore = 70
    @State private var numberOfQuestions: Double = 5
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var isNotesExpanded: Bool = true
    @State private var additionalNotes: String = ""

    private let timeLimitOptions = [15, 30, 45, 60]
    private let passingScoreOptions = [60, 70, 80, 90]

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var canGenerate: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedNoteIds.isEmpty
    }

    // Notes for source selection
    private var allSourceNotes: [(id: UUID, name: String, icon: String, type: String)] {
        course.notes.map { (id: $0.id, name: $0.name, icon: $0.fileTypeIcon, type: "Notes") }
    }

    private var selectedCount: Int {
        selectedNoteIds.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Topic Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        TextField("e.g., Chapters 1-5, Midterm review...", text: $topic)
                            .font(.quicksand(16, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            .padding(12)
                            .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Time Limit
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Limit")
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        HStack(spacing: 12) {
                            ForEach(timeLimitOptions, id: \.self) { minutes in
                                Button {
                                    selectedTimeLimit = minutes
                                } label: {
                                    Text("\(minutes) min")
                                        .font(.quicksand(14, weight: .medium))
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
                            .font(.quicksand(14, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        HStack(spacing: 12) {
                            ForEach(passingScoreOptions, id: \.self) { score in
                                Button {
                                    selectedPassingScore = score
                                } label: {
                                    Text("\(score)%")
                                        .font(.quicksand(14, weight: .medium))
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

                    // Number of Questions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Number of Questions")
                                .font(.quicksand(14, weight: .semiBold))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                            Spacer()

                            Text("\(Int(numberOfQuestions))")
                                .font(.quicksand(16, weight: .semiBold))
                                .foregroundColor(Color.vibrantTeal)
                        }

                        Slider(value: $numberOfQuestions, in: 1...10, step: 1)
                            .tint(Color.vibrantTeal)
                    }

                    // Source
                    sourceNotesSelector

                    // Additional Notes Field
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
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
            .overlay(alignment: .bottom) {
                // Generate Button
                Button {
                    generateExam()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Generate Exam")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.adaptiveBackground(for: effectiveColorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
                ToolbarItem(placement: .principal) {
                    Text("Generate Exam")
                        .font(.quicksand(18, weight: .semiBold))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
        .onAppear {
            // Pre-select all notes by default
            selectedNoteIds = Set(allSourceNotes.map { $0.id })
        }
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

    // MARK: - Source Selector

    private var sourceNotesSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with expand/collapse and select all
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isNotesExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isNotesExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Source (\(selectedCount) selected)")
                            .font(.quicksand(14, weight: .semiBold))
                    }
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    toggleSelectAll()
                } label: {
                    Text(selectedNoteIds.count == allSourceNotes.count ? "Deselect All" : "Select All")
                        .font(.quicksand(12, weight: .medium))
                        .foregroundColor(Color.vibrantTeal)
                }
                .buttonStyle(.plain)
            }

            // Notes list
            if isNotesExpanded {
                VStack(spacing: 0) {
                    if allSourceNotes.isEmpty {
                        HStack {
                            Text("No notes in this course")
                                .font(.quicksand(14, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                                .padding(.vertical, 12)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    } else {
                        ForEach(allSourceNotes, id: \.id) { sourceNote in
                            Button {
                                toggleNote(sourceNote.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedNoteIds.contains(sourceNote.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedNoteIds.contains(sourceNote.id) ? Color.vibrantTeal : Color.adaptiveText(for: effectiveColorScheme).opacity(0.4))

                                    Image(systemName: sourceNote.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                                        .frame(width: 24)

                                    Text(sourceNote.name)
                                        .font(.quicksand(14, weight: .regular))
                                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                                        .lineLimit(1)

                                    Spacer()

                                    Text(sourceNote.type)
                                        .font(.quicksand(10, weight: .medium))
                                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.08))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if sourceNote.id != allSourceNotes.last?.id {
                                Divider()
                                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))
                            }
                        }
                    }
                }
                .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func toggleNote(_ id: UUID) {
        if selectedNoteIds.contains(id) {
            selectedNoteIds.remove(id)
        } else {
            selectedNoteIds.insert(id)
        }
    }

    private func toggleSelectAll() {
        if selectedNoteIds.count == allSourceNotes.count {
            selectedNoteIds.removeAll()
        } else {
            selectedNoteIds = Set(allSourceNotes.map { $0.id })
        }
    }
}
