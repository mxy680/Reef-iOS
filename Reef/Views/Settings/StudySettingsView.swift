//
//  StudySettingsView.swift
//  Reef
//
//  Study settings tab for configuring quiz and exam defaults.
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
            VStack(spacing: 24) {
                // Quiz Defaults Section
                settingsSection(title: "Quiz Defaults") {
                    // Default Difficulty
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Difficulty")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        difficultyPicker(selection: $preferences.quizDefaultDifficulty)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

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
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

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
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Default Time Limit
                    HStack {
                        Text("Default Time Limit")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Picker("Time Limit", selection: $preferences.quizDefaultTimeLimit) {
                            ForEach(TimeLimitOption.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)
                }

                // Exam Defaults Section
                settingsSection(title: "Exam Defaults") {
                    // Default Difficulty
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Difficulty")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                        difficultyPicker(selection: $preferences.examDefaultDifficulty)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Default Passing Score
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Passing Score")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            Spacer()
                            Text("\(Int(preferences.examDefaultPassingScore))%")
                                .font(.quicksand(14, weight: .medium))
                                .foregroundColor(Color.oceanMid)
                        }
                        Slider(value: $preferences.examDefaultPassingScore, in: 50...100, step: 5)
                            .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Default Time Limit
                    HStack {
                        Text("Default Time Limit")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Picker("Time Limit", selection: $preferences.examDefaultTimeLimit) {
                            ForEach(TimeLimitOption.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Show Timer Toggle
                    Toggle(isOn: $preferences.examShowTimer) {
                        Text("Show Timer")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    }
                    .tint(Color.vibrantTeal)
                    .padding(.vertical, 4)
                }

                // Topic Weighting Section
                settingsSection(title: "Topic Weighting") {
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
                    .tint(Color.vibrantTeal)
                    .padding(.vertical, 4)

                    if preferences.focusOnWeakAreas {
                        Divider()
                            .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                        // Weak Area Weight
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Weak Area Weight")
                                    .font(.quicksand(16, weight: .medium))
                                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                                Spacer()
                                Text("\(Int(preferences.weakAreaWeight * 100))%")
                                    .font(.quicksand(14, weight: .medium))
                                    .foregroundColor(Color.oceanMid)
                            }
                            Slider(value: $preferences.weakAreaWeight, in: 0.5...1.0, step: 0.1)
                                .tint(Color.vibrantTeal)
                            Text("Higher weight means more questions from weak areas")
                                .font(.quicksand(12, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Helpers

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
                                .fill(selection.wrappedValue == level.rawValue ? Color.vibrantTeal : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.5) : Color.sageMist.opacity(0.7))
        )
    }

    private func questionTypeToggle(_ type: QuestionType) -> some View {
        Button {
            preferences.toggleQuestionType(type)
        } label: {
            HStack {
                Image(systemName: preferences.isQuestionTypeSelected(type) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(preferences.isQuestionTypeSelected(type) ? Color.vibrantTeal : Color.adaptiveText(for: effectiveColorScheme).opacity(0.5))
                Text(type.displayName)
                    .font(.quicksand(15, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.oceanMid)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(effectiveColorScheme == .dark ? Color.deepSea.opacity(0.3) : Color.sageMist.opacity(0.5))
            )
        }
    }
}

#Preview {
    StudySettingsView()
}
