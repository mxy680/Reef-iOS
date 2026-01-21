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
                    .font(.nunito(20, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                Text("Generate your first quiz to start practicing")
                    .font(.nunito(16, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
            }

            Button {
                onGenerateQuiz()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate Quiz")
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
}

// MARK: - Quiz Generation View (Placeholder)

struct QuizGenerationView: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Quiz generation coming soon")
                    .font(.nunito(18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
            .navigationTitle("New Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
    }
}
