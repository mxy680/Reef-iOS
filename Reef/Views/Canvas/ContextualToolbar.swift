//
//  ContextualToolbar.swift
//  Reef
//
//  Contextual options tier that appears above the main toolbar
//

import SwiftUI
import UIKit

// MARK: - Shared Constants

private let maxCustomColors = 4  // 3 default + 4 custom = 7 max

// MARK: - Color Swatch Component

struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    var isRemoving: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var isPressed: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? Color.white : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.3) : Color.clear,
                radius: 4
            )
            .scaleEffect(isRemoving ? 0.01 : (isPressed ? 0.85 : 1.0))
            .opacity(isRemoving ? 0 : 1)
            .rotationEffect(isRemoving ? .degrees(90) : .degrees(0))
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = pressing
                }
            }) {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onLongPress?()
            }
            .allowsHitTesting(onLongPress != nil || true)
    }
}

// MARK: - Thickness Slider View

struct ThicknessSliderView: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Small size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 4, height: 4)

            // Slider
            Slider(value: $value, in: range)
                .accentColor(.deepTeal)
                .frame(width: 100)

            // Large size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 12, height: 12)

            // Current size preview
            Circle()
                .fill(Color.adaptiveText(for: colorScheme))
                .frame(width: min(value, 16), height: min(value, 16))
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Color Helpers

private func colorsAreClose(_ color1: Color, _ color2: Color) -> Bool {
    let uiColor1 = UIColor(color1)
    let uiColor2 = UIColor(color2)

    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

    uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

    let threshold: CGFloat = 0.05
    return abs(r1 - r2) < threshold && abs(g1 - g2) < threshold && abs(b1 - b2) < threshold
}

// MARK: - Default Colors

private func defaultPenColors(for colorScheme: ColorScheme) -> [Color] {
    [
        colorScheme == .dark ? .white : .black,
        .deepTeal,
        Color(red: 0.9, green: 0.2, blue: 0.2)  // Red
    ]
}

private let defaultHighlighterColors: [Color] = [
    Color(red: 1.0, green: 0.92, blue: 0.23),   // Yellow
    Color(red: 0.6, green: 0.8, blue: 1.0),     // Blue
    Color(red: 1.0, green: 0.6, blue: 0.8)      // Pink
]

// MARK: - Pen Options View

struct PenOptionsView: View {
    @Binding var penWidth: CGFloat
    @Binding var selectedPenColor: Color
    @Binding var customPenColors: [Color]
    let colorScheme: ColorScheme

    @State private var penColorPickerColor: Color = .gray
    @State private var removingPenColorIndex: Int? = nil

    private var allPenColors: [Color] {
        defaultPenColors(for: colorScheme) + customPenColors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color swatches
            ForEach(Array(allPenColors.enumerated()), id: \.offset) { index, color in
                let defaults = defaultPenColors(for: colorScheme)
                let isCustomColor = index >= defaults.count
                let customIndex = index - defaults.count
                let isRemoving = isCustomColor && removingPenColorIndex == customIndex

                ColorSwatch(
                    color: color,
                    isSelected: selectedPenColor == color,
                    isRemoving: isRemoving,
                    onTap: { selectedPenColor = color },
                    onLongPress: isCustomColor ? {
                        removeCustomPenColor(at: customIndex)
                    } : nil
                )
            }

            // Add color button (if under max)
            if customPenColors.count < maxCustomColors {
                ColorPicker("", selection: $penColorPickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                            .allowsHitTesting(false)
                    )
                    .onChange(of: penColorPickerColor) { _, newColor in
                        if !allPenColors.contains(where: { colorsAreClose($0, newColor) }) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                customPenColors.append(newColor)
                            }
                            selectedPenColor = newColor
                        }
                    }
            }

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Thickness slider with preview
            ThicknessSliderView(
                value: $penWidth,
                range: StrokeWidthRange.penMin...StrokeWidthRange.penMax,
                colorScheme: colorScheme
            )
        }
    }

    private func removeCustomPenColor(at index: Int) {
        guard index >= 0 && index < customPenColors.count else { return }

        // If removing the selected color, switch to first default
        if colorsAreClose(selectedPenColor, customPenColors[index]) {
            selectedPenColor = defaultPenColors(for: colorScheme).first ?? .black
        }

        // Trigger removal animation
        withAnimation(.easeInOut(duration: 0.15)) {
            removingPenColorIndex = index
        }

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if index < customPenColors.count {
                    customPenColors.remove(at: index)
                }
                removingPenColorIndex = nil
            }
        }
    }
}

// MARK: - Highlighter Options View

struct HighlighterOptionsView: View {
    @Binding var highlighterWidth: CGFloat
    @Binding var selectedHighlighterColor: Color
    @Binding var customHighlighterColors: [Color]
    let colorScheme: ColorScheme

    @State private var highlighterColorPickerColor: Color = .gray
    @State private var removingHighlighterColorIndex: Int? = nil

    private var allHighlighterColors: [Color] {
        defaultHighlighterColors + customHighlighterColors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color swatches
            ForEach(Array(allHighlighterColors.enumerated()), id: \.offset) { index, color in
                let isCustomColor = index >= defaultHighlighterColors.count
                let customIndex = index - defaultHighlighterColors.count
                let isRemoving = isCustomColor && removingHighlighterColorIndex == customIndex

                ColorSwatch(
                    color: color,
                    isSelected: selectedHighlighterColor == color,
                    isRemoving: isRemoving,
                    onTap: { selectedHighlighterColor = color },
                    onLongPress: isCustomColor ? {
                        removeCustomHighlighterColor(at: customIndex)
                    } : nil
                )
            }

            // Add color button (if under max)
            if customHighlighterColors.count < maxCustomColors {
                ColorPicker("", selection: $highlighterColorPickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                            .allowsHitTesting(false)
                    )
                    .onChange(of: highlighterColorPickerColor) { _, newColor in
                        if !allHighlighterColors.contains(where: { colorsAreClose($0, newColor) }) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                customHighlighterColors.append(newColor)
                            }
                            selectedHighlighterColor = newColor
                        }
                    }
            }

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Thickness slider with preview
            ThicknessSliderView(
                value: $highlighterWidth,
                range: StrokeWidthRange.highlighterMin...StrokeWidthRange.highlighterMax,
                colorScheme: colorScheme
            )
        }
    }

    private func removeCustomHighlighterColor(at index: Int) {
        guard index >= 0 && index < customHighlighterColors.count else { return }

        // If removing the selected color, switch to first default
        if colorsAreClose(selectedHighlighterColor, customHighlighterColors[index]) {
            selectedHighlighterColor = defaultHighlighterColors.first ?? .yellow
        }

        // Trigger removal animation
        withAnimation(.easeInOut(duration: 0.15)) {
            removingHighlighterColorIndex = index
        }

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if index < customHighlighterColors.count {
                    customHighlighterColors.remove(at: index)
                }
                removingHighlighterColorIndex = nil
            }
        }
    }
}

// MARK: - Eraser Options View

struct EraserOptionsView: View {
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    let colorScheme: ColorScheme
    var onClearPage: () -> Void = {}

    private struct EraserPreset: Identifiable {
        let id: String
        let size: CGFloat
        let displaySize: CGFloat
    }

    private let presets: [EraserPreset] = [
        EraserPreset(id: "small", size: StrokeWidthRange.eraserSmall, displaySize: 10),
        EraserPreset(id: "medium", size: StrokeWidthRange.eraserMedium, displaySize: 16),
        EraserPreset(id: "large", size: StrokeWidthRange.eraserLarge, displaySize: 24),
    ]

    var body: some View {
        HStack(spacing: 12) {
            // Stroke eraser button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eraserType = .stroke
                }
            } label: {
                Image(systemName: "eraser.line.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(eraserType == .stroke ? .deepTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .stroke ? Color.deepTeal.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            // Pixel eraser button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eraserType = .bitmap
                }
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(eraserType == .bitmap ? .deepTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .bitmap ? Color.deepTeal.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Size preset buttons
            ForEach(presets) { preset in
                let isSelected = eraserSize == preset.size
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        eraserSize = preset.size
                    }
                } label: {
                    Circle()
                        .fill(isSelected ? Color.deepTeal : Color.adaptiveText(for: colorScheme).opacity(0.4))
                        .frame(width: preset.displaySize, height: preset.displaySize)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.deepTeal.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Clear page button
            Button(action: onClearPage) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Text Options View

struct TextOptionsView: View {
    @Binding var textSize: CGFloat
    @Binding var textColor: Color
    @Binding var customPenColors: [Color]
    let colorScheme: ColorScheme

    @State private var colorPickerColor: Color = .gray

    private var allColors: [Color] {
        defaultPenColors(for: colorScheme) + customPenColors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color swatches (reuse pen colors)
            ForEach(Array(allColors.enumerated()), id: \.offset) { _, color in
                ColorSwatch(
                    color: color,
                    isSelected: textColor == color,
                    onTap: { textColor = color }
                )
            }

            // Add color button
            if customPenColors.count < 4 {
                ColorPicker("", selection: $colorPickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                            .allowsHitTesting(false)
                    )
                    .onChange(of: colorPickerColor) { _, newColor in
                        if !allColors.contains(where: { colorsAreClose($0, newColor) }) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                customPenColors.append(newColor)
                            }
                            textColor = newColor
                        }
                    }
            }

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Font size slider
            HStack(spacing: 8) {
                Text("A")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))

                Slider(value: $textSize, in: 10...48, step: 1)
                    .accentColor(.deepTeal)
                    .frame(width: 100)

                Text("A")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))

                Text("\(Int(textSize))pt")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(width: 36)
            }
        }
    }
}

