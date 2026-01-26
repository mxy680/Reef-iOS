//
//  ContextualToolbar.swift
//  Reef
//
//  Contextual options tier that appears above the main toolbar
//

import SwiftUI
import UIKit

// MARK: - Lasso Action Type

private enum LassoAction: String, CaseIterable {
    case copy, cut, delete
}

// MARK: - Contextual Toolbar

struct ContextualToolbar: View {
    let selectedTool: CanvasTool
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    @Binding var customPenColors: [Color]
    @Binding var customHighlighterColors: [Color]
    let colorScheme: ColorScheme

    // Lasso actions
    var canPaste: Bool = false
    var hasSelection: Bool = false
    var onCopy: (() -> Void)? = nil
    var onCut: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onPaste: (() -> Void)? = nil

    var onClose: (() -> Void)? = nil

    private static let maxCustomColors = 4  // 3 default + 4 custom = 7 max

    private var defaultPenColors: [Color] {
        [
            colorScheme == .dark ? .white : .black,
            .vibrantTeal,
            Color(red: 0.9, green: 0.2, blue: 0.2)  // Red
        ]
    }

    private let defaultHighlighterColors: [Color] = [
        Color(red: 1.0, green: 0.92, blue: 0.23),   // Yellow
        Color(red: 0.6, green: 0.8, blue: 1.0),     // Blue
        Color(red: 1.0, green: 0.6, blue: 0.8)      // Pink
    ]

    private var allPenColors: [Color] {
        defaultPenColors + customPenColors
    }

    private var allHighlighterColors: [Color] {
        defaultHighlighterColors + customHighlighterColors
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                switch selectedTool {
                case .pen:
                    penOptions
                case .highlighter:
                    highlighterOptions
                case .eraser:
                    eraserOptions
                case .lasso:
                    lassoOptions
                }
            }

            if onClose != nil {
                // Divider before close button
                Rectangle()
                    .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                    .frame(width: 1, height: 24)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)

                // Close button
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.6))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color.deepOcean : Color.lightGrayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.15) : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.15),
                    radius: colorScheme == .dark ? 12 : 8,
                    x: 0,
                    y: 4
                )
        )
    }

    // MARK: - Pen Options

    @State private var penColorPickerColor: Color = .gray
    @State private var removingPenColorIndex: Int? = nil

    private var penOptions: some View {
        HStack(spacing: 12) {
            // Thickness slider with preview
            thicknessSlider(
                value: $penWidth,
                range: StrokeWidthRange.penMin...StrokeWidthRange.penMax
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Color swatches
            ForEach(Array(allPenColors.enumerated()), id: \.offset) { index, color in
                let isCustomColor = index >= defaultPenColors.count
                let customIndex = index - defaultPenColors.count
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
            if customPenColors.count < Self.maxCustomColors {
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
        }
    }

    private func removeCustomPenColor(at index: Int) {
        guard index >= 0 && index < customPenColors.count else { return }

        // If removing the selected color, switch to first default
        if colorsAreClose(selectedPenColor, customPenColors[index]) {
            selectedPenColor = defaultPenColors.first ?? .black
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

    // MARK: - Highlighter Options

    @State private var highlighterColorPickerColor: Color = .gray
    @State private var removingHighlighterColorIndex: Int? = nil

    private var highlighterOptions: some View {
        HStack(spacing: 12) {
            // Thickness slider with preview
            thicknessSlider(
                value: $highlighterWidth,
                range: StrokeWidthRange.highlighterMin...StrokeWidthRange.highlighterMax
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

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
            if customHighlighterColors.count < Self.maxCustomColors {
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

    // MARK: - Eraser Options

    private var eraserOptions: some View {
        HStack(spacing: 12) {
            // Stroke eraser button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eraserType = .stroke
                }
            } label: {
                Image(systemName: "eraser.line.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(eraserType == .stroke ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .stroke ? Color.vibrantTeal.opacity(0.15) : Color.clear)
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
                    .foregroundColor(eraserType == .bitmap ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(eraserType == .bitmap ? Color.vibrantTeal.opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            thicknessSlider(
                value: $eraserSize,
                range: StrokeWidthRange.eraserMin...StrokeWidthRange.eraserMax
            )
            .opacity(eraserType == .bitmap ? 1.0 : 0.35)
            .disabled(eraserType == .stroke)
            .animation(.easeInOut(duration: 0.2), value: eraserType)
        }
    }

    // MARK: - Lasso Options

    @State private var showingTooltip: LassoAction? = nil

    private var lassoOptions: some View {
        HStack(spacing: 4) {
            // Copy button (disabled - selection state unknown)
            LassoActionButton(
                icon: "doc.on.doc",
                label: "Copy",
                isEnabled: false,
                colorScheme: colorScheme,
                showingTooltip: $showingTooltip,
                tooltipAction: .copy,
                action: { onCopy?() }
            )

            // Cut button (disabled - selection state unknown)
            LassoActionButton(
                icon: "scissors",
                label: "Cut",
                isEnabled: false,
                colorScheme: colorScheme,
                showingTooltip: $showingTooltip,
                tooltipAction: .cut,
                action: { onCut?() }
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Paste button (enabled when clipboard has content)
            LassoActionButton(
                icon: "doc.on.clipboard",
                label: "Paste",
                isEnabled: canPaste,
                colorScheme: colorScheme,
                showingTooltip: .constant(nil),
                tooltipAction: nil,
                action: { onPaste?() }
            )

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Delete button (disabled - selection state unknown)
            LassoActionButton(
                icon: "trash",
                label: "Delete",
                isEnabled: false,
                isDestructive: true,
                colorScheme: colorScheme,
                showingTooltip: $showingTooltip,
                tooltipAction: .delete,
                action: { onDelete?() }
            )
        }
    }

    // MARK: - Thickness Slider

    private func thicknessSlider(value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 8) {
            // Small size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 4, height: 4)

            // Slider
            Slider(value: value, in: range)
                .accentColor(.vibrantTeal)
                .frame(width: 100)

            // Large size indicator
            Circle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.5))
                .frame(width: 12, height: 12)

            // Current size preview
            Circle()
                .fill(Color.adaptiveText(for: colorScheme))
                .frame(width: min(value.wrappedValue, 16), height: min(value.wrappedValue, 16))
                .frame(width: 20, height: 20)
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

}

#Preview {
    VStack(spacing: 20) {
        ContextualToolbar(
            selectedTool: .pen,
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.stroke),
            selectedPenColor: .constant(.black),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
            customPenColors: .constant([]),
            customHighlighterColors: .constant([]),
            colorScheme: .light,
            onClose: {}
        )

        ContextualToolbar(
            selectedTool: .eraser,
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.bitmap),
            selectedPenColor: .constant(.black),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
            customPenColors: .constant([]),
            customHighlighterColors: .constant([]),
            colorScheme: .dark,
            onClose: {}
        )

        ContextualToolbar(
            selectedTool: .lasso,
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.stroke),
            selectedPenColor: .constant(.black),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
            customPenColors: .constant([]),
            customHighlighterColors: .constant([]),
            colorScheme: .light,
            canPaste: true,
            onCopy: {},
            onCut: {},
            onDelete: {},
            onPaste: {},
            onClose: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}

// MARK: - Color Swatch Component

private struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let isRemoving: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

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

// MARK: - Lasso Action Button Component

private struct LassoActionButton: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    var isDestructive: Bool = false
    let colorScheme: ColorScheme
    @Binding var showingTooltip: LassoAction?
    let tooltipAction: LassoAction?
    let action: () -> Void

    private var foregroundColor: Color {
        if isEnabled {
            return isDestructive ? .deleteRed : Color.adaptiveText(for: colorScheme)
        } else {
            return isDestructive
                ? Color.deleteRed.opacity(0.35)
                : Color.adaptiveText(for: colorScheme).opacity(0.35)
        }
    }

    private var isShowingTooltip: Bool {
        guard let tooltipAction = tooltipAction else { return false }
        return showingTooltip == tooltipAction
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Tooltip positioned above
            if isShowingTooltip {
                TooltipView(colorScheme: colorScheme)
                    .offset(y: -38)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }

            // Button
            Button {
                if isEnabled {
                    action()
                } else if let tooltipAction = tooltipAction {
                    // Show tooltip for disabled button
                    withAnimation(.easeOut(duration: 0.15)) {
                        showingTooltip = tooltipAction
                    }
                    // Auto-dismiss after 1.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if showingTooltip == tooltipAction {
                                showingTooltip = nil
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(foregroundColor)
                .frame(width: 48, height: 40)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Tooltip View

private struct TooltipView: View {
    let colorScheme: ColorScheme

    var body: some View {
        Text("Select strokes first")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.95))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
    }
}
