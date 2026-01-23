//
//  AISettingsView.swift
//  Reef
//
//  AI settings tab for configuring reasoning models and feedback behavior.
//

import SwiftUI

struct AISettingsView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Reasoning Model Section
                settingsSection(title: "Reasoning Model") {
                    HStack {
                        Text("Model")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Picker("Model", selection: $preferences.reasoningModel) {
                            ForEach(ReasoningModel.allCases) { model in
                                Text(model.displayName).tag(model.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vibrantTeal)
                    }
                }

                // Feedback Behavior Section
                settingsSection(title: "Feedback Behavior") {
                    // Pause Detection Sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pause Detection Sensitivity")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            Spacer()
                            Text(sensitivityLabel)
                                .font(.quicksand(14, weight: .regular))
                                .foregroundColor(Color.oceanMid)
                        }
                        Slider(value: $preferences.pauseDetectionSensitivity, in: 0...1)
                            .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Auto-Feedback Toggle
                    Toggle(isOn: $preferences.autoFeedbackEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Feedback")
                                .font(.quicksand(16, weight: .medium))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                            Text("Automatically provide feedback during pauses")
                                .font(.quicksand(13, weight: .regular))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.6))
                        }
                    }
                    .tint(Color.vibrantTeal)
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Feedback Detail Level
                    HStack {
                        Text("Feedback Detail Level")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Picker("Detail Level", selection: $preferences.feedbackDetailLevel) {
                            ForEach(FeedbackDetailLevel.allCases) { level in
                                Text(level.rawValue).tag(level.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)
                }

                // Handwriting Recognition Section
                settingsSection(title: "Handwriting Recognition") {
                    // Model Info
                    HStack {
                        Text("Recognition Model")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text("Gemini 3 Pro")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color.oceanMid)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.oceanMid.opacity(0.1))
                            )
                    }
                    .padding(.vertical, 4)

                    Divider()
                        .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.1))

                    // Recognition Language
                    HStack {
                        Text("Recognition Language")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Picker("Language", selection: $preferences.recognitionLanguage) {
                            ForEach(RecognitionLanguage.allCases) { language in
                                Text(language.rawValue).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vibrantTeal)
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }

    // MARK: - Helpers

    private var sensitivityLabel: String {
        switch preferences.pauseDetectionSensitivity {
        case 0..<0.33: return "Low"
        case 0.33..<0.66: return "Medium"
        default: return "High"
        }
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
    AISettingsView()
}
