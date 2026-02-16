//
//  StudySettingsView.swift
//  Reef
//
//  Study settings for configuring quiz and exam defaults.
//

import SwiftUI

struct StudySettingsView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sectionHeader("Quiz Defaults", isFirst: true)

                // Default Difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Difficulty")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                    difficultyPicker(selection: $preferences.quizDefaultDifficulty)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Default Question Count
                HStack {
                    Text("Default Question Count")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    Stepper(
                        "\(preferences.quizDefaultQuestionCount)",
                        value: $preferences.quizDefaultQuestionCount,
                        in: 5...50,
                        step: 5
                    )
                    .font(.quicksand(16, weight: .medium))
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Preferred Question Types
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred Question Types")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                    VStack(spacing: 8) {
                        ForEach(QuestionType.allCases) { type in
                            questionTypeToggle(type)
                        }
                    }
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Default Time Limit
                HStack {
                    Text("Default Time Limit")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.quizDefaultTimeLimit,
                        options: TimeLimitOption.allCases,
                        displayName: { $0.rawValue },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)

                sectionHeader("Exam Defaults")

                // Default Difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Difficulty")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                    difficultyPicker(selection: $preferences.examDefaultDifficulty)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Default Passing Score
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Passing Score")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text("\(Int(preferences.examDefaultPassingScore))%")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color.deepTeal)
                    }
                    Slider(value: $preferences.examDefaultPassingScore, in: 50...100, step: 5)
                        .tint(Color.deepTeal)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Default Time Limit
                HStack {
                    Text("Default Time Limit")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.examDefaultTimeLimit,
                        options: TimeLimitOption.allCases,
                        displayName: { $0.rawValue },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                // Show Timer Toggle
                Toggle(isOn: $preferences.examShowTimer) {
                    Text("Show Timer")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                }
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                sectionHeader("Topic Weighting")

                // Focus on Weak Areas Toggle
                Toggle(isOn: $preferences.focusOnWeakAreas) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus on Weak Areas")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Text("Prioritize topics you've struggled with")
                            .font(.quicksand(13, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                    }
                }
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                if preferences.focusOnWeakAreas {
                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))
                        .padding(.vertical, 12)

                    // Weak Area Weight
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weak Area Weight")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            Spacer()
                            Text("\(Int(preferences.weakAreaWeight * 100))%")
                                .font(.quicksand(14, weight: .medium))
                                .foregroundColor(Color.deepTeal)
                        }
                        Slider(value: $preferences.weakAreaWeight, in: 0.5...1.0, step: 0.1)
                            .tint(Color.deepTeal)
                        Text("Higher weight means more questions from weak areas")
                            .font(.quicksand(12, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(effectiveColorScheme == .dark ? Color.warmDarkCard : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(effectiveColorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
            )
            .padding(32)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, isFirst: Bool = false) -> some View {
        Text(title)
            .font(.quicksand(13, weight: .semiBold))
            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isFirst ? 0 : 32)
            .padding(.bottom, 12)
    }

    private func difficultyPicker(selection: Binding<String>) -> some View {
        HStack(spacing: 0) {
            ForEach(DifficultyLevel.allCases) { level in
                Button {
                    selection.wrappedValue = level.rawValue
                } label: {
                    Text(level.rawValue)
                        .font(.quicksand(14, weight: .semiBold))
                        .foregroundColor(selection.wrappedValue == level.rawValue ? .white : Color.adaptiveText(for: effectiveColorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection.wrappedValue == level.rawValue ? Color.deepTeal : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(effectiveColorScheme == .dark ? Color.warmDarkCard : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(effectiveColorScheme == .dark ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func questionTypeToggle(_ type: QuestionType) -> some View {
        Button {
            preferences.toggleQuestionType(type)
        } label: {
            HStack {
                Image(systemName: preferences.isQuestionTypeSelected(type) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(preferences.isQuestionTypeSelected(type) ? Color.deepTeal : Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                Text(type.displayName)
                    .font(.quicksand(15, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func styledPicker<T: Hashable & Identifiable>(
        selection: Binding<String>,
        options: [T],
        displayName: @escaping (T) -> String,
        rawValue: @escaping (T) -> String
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = rawValue(option)
                } label: {
                    HStack {
                        Text(displayName(option))
                        if selection.wrappedValue == rawValue(option) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(options.first { rawValue($0) == selection.wrappedValue }.map { displayName($0) } ?? "Select")
                    .font(.quicksand(14, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Color.deepTeal)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.deepTeal.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    NavigationStack {
        StudySettingsView()
    }
}
