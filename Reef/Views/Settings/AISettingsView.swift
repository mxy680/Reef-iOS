//
//  AISettingsView.swift
//  Reef
//
//  AI settings for configuring reasoning models and feedback behavior.
//

import SwiftUI

struct AISettingsView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 0) {
                sectionHeader("Reasoning Model", isFirst: true)

                HStack {
                    Text("Model")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.reasoningModel,
                        options: ReasoningModel.allCases,
                        displayName: { $0.displayName },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)

                sectionHeader("Feedback Behavior")

                // Pause Detection Sensitivity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pause Detection Sensitivity")
                            .font(.quicksand(16, weight: .medium))
                            .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        Spacer()
                        Text(sensitivityLabel)
                            .font(.quicksand(14, weight: .regular))
                            .foregroundColor(Color.deepTeal)
                    }
                    Slider(value: $preferences.pauseDetectionSensitivity, in: 0...1)
                        .tint(Color.deepTeal)
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

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
                .tint(Color.deepTeal)
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                HStack {
                    Text("Feedback Detail Level")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.feedbackDetailLevel,
                        options: FeedbackDetailLevel.allCases,
                        displayName: { $0.rawValue },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)

                sectionHeader("Handwriting Recognition")

                HStack {
                    Text("Recognition Model")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.handwritingModel,
                        options: HandwritingModel.allCases,
                        displayName: { $0.displayName },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)

                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.06))
                    .padding(.vertical, 12)

                HStack {
                    Text("Recognition Language")
                        .font(.quicksand(16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                    styledPicker(
                        selection: $preferences.recognitionLanguage,
                        options: RecognitionLanguage.allCases,
                        displayName: { $0.rawValue },
                        rawValue: { $0.rawValue }
                    )
                }
                .frame(minHeight: 44)
            }
            .padding(24)
            .frame(minHeight: geo.size.height - 64)
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
        }
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var sensitivityLabel: String {
        switch preferences.pauseDetectionSensitivity {
        case 0..<0.33: return "Low"
        case 0.33..<0.66: return "Medium"
        default: return "High"
        }
    }

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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.deepTeal.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
