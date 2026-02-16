//
//  TutorDetailPopup.swift
//  Reef
//
//  Overlay popup for viewing a tutor's profile and customizing teaching behavior.
//

import SwiftUI

struct TutorDetailPopup: View {
    let tutor: Tutor
    let isCurrentlySelected: Bool
    let colorScheme: ColorScheme
    let onSelect: (Tutor, TutorPresetMode?) -> Void
    let onDismiss: () -> Void

    @State private var selectedPresetID: String?
    @State private var patience: Double = 0.5
    @State private var hintFrequency: Double = 0.5
    @State private var explanationDepth: Double = 0.5
    @State private var isVisible = false
    @State private var isManualSliderChange = false

    private var cardBackgroundColor: Color {
        Color.adaptiveCardBackground(for: colorScheme)
    }

    private var fieldBackgroundColor: Color {
        colorScheme == .dark ? Color.warmDark : Color.blushWhite
    }

    init(
        tutor: Tutor,
        isCurrentlySelected: Bool,
        colorScheme: ColorScheme,
        initialPresetID: String?,
        initialPatience: Double,
        initialHintFrequency: Double,
        initialExplanationDepth: Double,
        onSelect: @escaping (Tutor, TutorPresetMode?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.tutor = tutor
        self.isCurrentlySelected = isCurrentlySelected
        self.colorScheme = colorScheme
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        _selectedPresetID = State(initialValue: initialPresetID)
        _patience = State(initialValue: initialPatience)
        _hintFrequency = State(initialValue: initialHintFrequency)
        _explanationDepth = State(initialValue: initialExplanationDepth)
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissPopup() }

            // Popup card
            VStack(spacing: 0) {
                popupHeader
                ScrollView {
                    VStack(spacing: 24) {
                        profileSection
                        presetModesSection
                        fineTuneSection
                        actionButtons
                    }
                    .padding(24)
                }
            }
            .frame(width: 420, maxHeight: 600)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.15), radius: 32, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    // MARK: - Header

    private var popupHeader: some View {
        HStack {
            Image(systemName: tutor.avatarSymbol)
                .font(.system(size: 20))
            Text(tutor.name)
                .font(.dynaPuff(18, weight: .semiBold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(tutor.accentColor)
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(spacing: 12) {
            // Large avatar
            ZStack {
                Circle()
                    .fill(tutor.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: tutor.avatarSymbol)
                    .font(.system(size: 36))
                    .foregroundColor(tutor.accentColor)
            }

            Text(tutor.name)
                .font(.dynaPuff(20, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            // Specialty badge
            Text(tutor.specialty)
                .font(.quicksand(13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .brightTealDark : .deepTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.deepTeal.opacity(colorScheme == .dark ? 0.15 : 0.1))
                )

            // Backstory
            Text(tutor.backstory)
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Preset Modes

    private var presetModesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Teaching Style")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            HStack(spacing: 8) {
                ForEach(tutor.presetModes) { preset in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedPresetID = preset.id
                            isManualSliderChange = false
                            patience = preset.patience
                            hintFrequency = preset.hintFrequency
                            explanationDepth = preset.explanationDepth
                        }
                    } label: {
                        Text(preset.name)
                            .font(.quicksand(13, weight: .medium))
                            .foregroundColor(selectedPresetID == preset.id ? .white : Color.adaptiveText(for: colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedPresetID == preset.id ? Color.deepTeal : fieldBackgroundColor)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedPresetID == preset.id ? Color.clear : Color.gray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Fine Tune Sliders

    private var fineTuneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fine Tune")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: colorScheme))

            sliderRow(label: "Patience", value: $patience, low: "Direct", high: "Patient")
            sliderRow(label: "Hints", value: $hintFrequency, low: "Rare", high: "Frequent")
            sliderRow(label: "Explanation Style", value: $explanationDepth, low: "Brief", high: "Detailed")
        }
    }

    private func sliderRow(label: String, value: Binding<Double>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.quicksand(13, weight: .medium))
                .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))

            Slider(value: value, in: 0...1) { editing in
                if editing {
                    selectedPresetID = nil
                }
            }
            .tint(.deepTeal)

            HStack {
                Text(low)
                    .font(.quicksand(11, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
                Spacer()
                Text(high)
                    .font(.quicksand(11, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondaryText(for: colorScheme))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { dismissPopup() } label: {
                Text("Cancel")
                    .font(.quicksand(16, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(fieldBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                let preset = tutor.presetModes.first { $0.id == selectedPresetID }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSelect(tutor, preset)
                }
            } label: {
                Text(isCurrentlySelected ? "Active" : "Select Tutor")
                    .font(.quicksand(16, weight: .semiBold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isCurrentlySelected ? Color.adaptiveSecondaryText(for: colorScheme) : Color.deepTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isCurrentlySelected)
        }
    }

    // MARK: - Dismiss

    private func dismissPopup() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
