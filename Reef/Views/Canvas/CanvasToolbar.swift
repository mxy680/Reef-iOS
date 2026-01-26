//
//  CanvasToolbar.swift
//  Reef
//
//  Floating toolbar with pencil, eraser, color picker, and home button
//

import SwiftUI

// MARK: - Tool Types

enum CanvasTool: Equatable {
    case pen
    case highlighter
    case eraser
    case diagram
}

enum EraserType: String, CaseIterable {
    case stroke = "Stroke"
    case bitmap = "Pixel"
}

enum CanvasBackgroundMode: String, CaseIterable {
    case normal
    case grid
    case dotted
    case lined

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .grid: return "Grid"
        case .dotted: return "Dotted"
        case .lined: return "Lined"
        }
    }

    var iconName: String {
        switch self {
        case .normal: return "rectangle"
        case .grid: return "grid"
        case .dotted: return "circle.grid.3x3"
        case .lined: return "line.3.horizontal"
        }
    }
}

// MARK: - Stroke Width Constants

enum StrokeWidthRange {
    static let penMin: CGFloat = 1
    static let penMax: CGFloat = 24
    static let penDefault: CGFloat = 4

    static let highlighterMin: CGFloat = 4
    static let highlighterMax: CGFloat = 24
    static let highlighterDefault: CGFloat = 12

    static let eraserMin: CGFloat = 8
    static let eraserMax: CGFloat = 48
    static let eraserDefault: CGFloat = 16
}

// MARK: - Canvas Toolbar

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedPenColor: Color
    @Binding var selectedHighlighterColor: Color
    @Binding var penWidth: CGFloat
    @Binding var highlighterWidth: CGFloat
    @Binding var eraserSize: CGFloat
    @Binding var eraserType: EraserType
    @Binding var customPenColors: [Color]
    @Binding var customHighlighterColors: [Color]
    @Binding var canvasBackgroundMode: CanvasBackgroundMode
    @Binding var canvasBackgroundOpacity: CGFloat
    @Binding var canvasBackgroundSpacing: CGFloat
    let colorScheme: ColorScheme
    let canUndo: Bool
    let canRedo: Bool
    let onHomePressed: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onAIPressed: () -> Void
    let onToggleDarkMode: () -> Void

    @State private var contextualToolbarHidden: Bool = false
    @State private var backgroundModeSelected: Bool = false

    private var toolHasContextualMenu: Bool {
        switch selectedTool {
        case .pen, .highlighter, .eraser, .diagram:
            return true
        }
    }

    private var showToolContextualToolbar: Bool {
        guard !backgroundModeSelected else { return false }
        switch selectedTool {
        case .pen, .highlighter, .eraser, .diagram:
            return !contextualToolbarHidden
        }
    }

    private var showBackgroundModeToolbar: Bool {
        backgroundModeSelected
    }

    private func selectTool(_ tool: CanvasTool) {
        // Deselect background mode when selecting a drawing tool
        backgroundModeSelected = false

        if selectedTool == tool && toolHasContextualMenu {
            contextualToolbarHidden.toggle()
        } else {
            selectedTool = tool
            contextualToolbarHidden = false
        }
    }

    private func selectBackgroundMode() {
        if backgroundModeSelected {
            // Toggle off if already selected
            backgroundModeSelected = false
        } else {
            // Select background mode, hide tool contextual toolbar
            backgroundModeSelected = true
            contextualToolbarHidden = true
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Tool contextual tier
            if showToolContextualToolbar {
                ContextualToolbar(
                    selectedTool: selectedTool,
                    penWidth: $penWidth,
                    highlighterWidth: $highlighterWidth,
                    eraserSize: $eraserSize,
                    eraserType: $eraserType,
                    selectedPenColor: $selectedPenColor,
                    selectedHighlighterColor: $selectedHighlighterColor,
                    customPenColors: $customPenColors,
                    customHighlighterColors: $customHighlighterColors,
                    colorScheme: colorScheme,
                    onClose: { contextualToolbarHidden = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Background mode contextual tier
            if showBackgroundModeToolbar {
                BackgroundModeToolbar(
                    canvasBackgroundMode: $canvasBackgroundMode,
                    canvasBackgroundOpacity: $canvasBackgroundOpacity,
                    canvasBackgroundSpacing: $canvasBackgroundSpacing,
                    colorScheme: colorScheme,
                    onClose: { backgroundModeSelected = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main toolbar
            mainToolbar
        }
        .animation(.easeOut(duration: 0.2), value: showToolContextualToolbar)
        .animation(.easeOut(duration: 0.2), value: showBackgroundModeToolbar)
        .animation(.easeOut(duration: 0.2), value: selectedTool)
        .animation(.easeOut(duration: 0.2), value: contextualToolbarHidden)
        .animation(.easeOut(duration: 0.2), value: backgroundModeSelected)
    }

    private var mainToolbar: some View {
        HStack(spacing: 0) {
            // Home button
            ToolbarButton(
                icon: "house.fill",
                isSelected: false,
                colorScheme: colorScheme,
                action: onHomePressed
            )

            toolbarDivider

            // Drawing tools
            ToolbarButton(
                icon: "pencil.tip",
                isSelected: selectedTool == .pen,
                colorScheme: colorScheme,
                action: { selectTool(.pen) }
            )

            ToolbarButton(
                icon: "highlighter",
                isSelected: selectedTool == .highlighter,
                colorScheme: colorScheme,
                action: { selectTool(.highlighter) }
            )

            ToolbarButton(
                icon: "eraser.fill",
                isSelected: selectedTool == .eraser,
                colorScheme: colorScheme,
                action: { selectTool(.eraser) }
            )

            ToolbarButton(
                icon: "triangle",
                isSelected: selectedTool == .diagram,
                colorScheme: colorScheme,
                action: { selectTool(.diagram) }
            )

            // Background mode button
            ToolbarButton(
                icon: "squareshape.split.3x3",
                isSelected: backgroundModeSelected,
                colorScheme: colorScheme,
                action: selectBackgroundMode
            )

            toolbarDivider

            // Undo/Redo
            ToolbarButton(
                icon: "arrow.uturn.backward",
                isSelected: false,
                isDisabled: !canUndo,
                colorScheme: colorScheme,
                action: onUndo
            )

            ToolbarButton(
                icon: "arrow.uturn.forward",
                isSelected: false,
                isDisabled: !canRedo,
                colorScheme: colorScheme,
                action: onRedo
            )

            toolbarDivider

            // AI button
            ToolbarButton(
                icon: "sparkles",
                isSelected: false,
                colorScheme: colorScheme,
                action: onAIPressed
            )

            toolbarDivider

            // Dark mode toggle
            ToolbarButton(
                icon: colorScheme == .dark ? "sun.max.fill" : "moon.fill",
                isSelected: false,
                colorScheme: colorScheme,
                action: onToggleDarkMode
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(colorScheme == .dark ? Color.deepOcean : Color.lightGrayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
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

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 8)
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isDisabled: Bool = false
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ?
                        Color.vibrantTeal.opacity(0.15) :
                        Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return Color.adaptiveText(for: colorScheme).opacity(0.3)
        }
        if isSelected {
            return .vibrantTeal
        }
        return Color.adaptiveText(for: colorScheme)
    }
}

// MARK: - Background Mode Toolbar

private struct BackgroundModeToolbar: View {
    @Binding var canvasBackgroundMode: CanvasBackgroundMode
    @Binding var canvasBackgroundOpacity: CGFloat
    @Binding var canvasBackgroundSpacing: CGFloat
    let colorScheme: ColorScheme
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CanvasBackgroundMode.allCases, id: \.self) { mode in
                Button {
                    canvasBackgroundMode = mode
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 24, height: 24)
                        Text(mode.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(canvasBackgroundMode == mode ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 56, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canvasBackgroundMode == mode ? Color.vibrantTeal.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            // Opacity slider (always visible, disabled when normal)
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // Opacity slider
            HStack(spacing: 4) {
                Image(systemName: "sun.min")
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(canvasBackgroundMode == .normal ? 0.2 : 0.5))

                Slider(value: $canvasBackgroundOpacity, in: 0.05...0.5)
                    .accentColor(.vibrantTeal)
                    .frame(width: 60)
                    .disabled(canvasBackgroundMode == .normal)

                Image(systemName: "sun.max")
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(canvasBackgroundMode == .normal ? 0.2 : 0.5))
            }
            .opacity(canvasBackgroundMode == .normal ? 0.4 : 1.0)

            // Spacing slider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 6)

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(canvasBackgroundMode == .normal ? 0.2 : 0.5))

                Slider(value: $canvasBackgroundSpacing, in: 24...80)
                    .accentColor(.vibrantTeal)
                    .frame(width: 60)
                    .disabled(canvasBackgroundMode == .normal)

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(canvasBackgroundMode == .normal ? 0.2 : 0.5))
            }
            .opacity(canvasBackgroundMode == .normal ? 0.4 : 1.0)

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
}

#Preview {
    VStack {
        CanvasToolbar(
            selectedTool: .constant(.pen),
            selectedPenColor: .constant(.inkBlack),
            selectedHighlighterColor: .constant(Color(red: 1.0, green: 0.92, blue: 0.23)),
            penWidth: .constant(StrokeWidthRange.penDefault),
            highlighterWidth: .constant(StrokeWidthRange.highlighterDefault),
            eraserSize: .constant(StrokeWidthRange.eraserDefault),
            eraserType: .constant(.stroke),
            customPenColors: .constant([]),
            customHighlighterColors: .constant([]),
            canvasBackgroundMode: .constant(.normal),
            canvasBackgroundOpacity: .constant(0.15),
            canvasBackgroundSpacing: .constant(48),
            colorScheme: .light,
            canUndo: true,
            canRedo: false,
            onHomePressed: {},
            onUndo: {},
            onRedo: {},
            onAIPressed: {},
            onToggleDarkMode: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
