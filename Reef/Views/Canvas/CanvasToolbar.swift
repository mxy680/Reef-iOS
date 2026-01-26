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
    case lasso
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
    let colorScheme: ColorScheme
    let canUndo: Bool
    let canRedo: Bool
    let canPaste: Bool
    let onHomePressed: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onPaste: () -> Void
    let onAIPressed: () -> Void
    let onToggleDarkMode: () -> Void

    @State private var contextualToolbarHidden: Bool = false

    private var toolHasContextualMenu: Bool {
        switch selectedTool {
        case .pen, .highlighter, .eraser:
            return true
        case .lasso:
            return false
        }
    }

    private var showContextualToolbar: Bool {
        switch selectedTool {
        case .pen, .highlighter, .eraser:
            return !contextualToolbarHidden
        case .lasso:
            return false
        }
    }

    private func selectTool(_ tool: CanvasTool) {
        if selectedTool == tool && toolHasContextualMenu {
            contextualToolbarHidden.toggle()
        } else {
            selectedTool = tool
            contextualToolbarHidden = false
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Contextual tier
            if showContextualToolbar {
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

            // Main toolbar
            mainToolbar
        }
        .animation(.easeOut(duration: 0.2), value: showContextualToolbar)
        .animation(.easeOut(duration: 0.2), value: selectedTool)
        .animation(.easeOut(duration: 0.2), value: contextualToolbarHidden)
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

            // Background mode menu
            Menu {
                ForEach(CanvasBackgroundMode.allCases, id: \.self) { mode in
                    Button(action: { canvasBackgroundMode = mode }) {
                        Label(mode.displayName, systemImage: mode.iconName)
                    }
                }
            } label: {
                Image(systemName: canvasBackgroundMode.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(canvasBackgroundMode != .normal ? .vibrantTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .background(
                        canvasBackgroundMode != .normal ?
                            Color.vibrantTeal.opacity(0.15) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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
                icon: "lasso",
                isSelected: selectedTool == .lasso,
                colorScheme: colorScheme,
                action: { selectTool(.lasso) }
            )

            toolbarDivider

            // Undo/Redo/Paste
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

            ToolbarButton(
                icon: "doc.on.clipboard",
                isSelected: false,
                isDisabled: !canPaste,
                colorScheme: colorScheme,
                action: onPaste
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
            colorScheme: .light,
            canUndo: true,
            canRedo: false,
            canPaste: true,
            onHomePressed: {},
            onUndo: {},
            onRedo: {},
            onPaste: {},
            onAIPressed: {},
            onToggleDarkMode: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
