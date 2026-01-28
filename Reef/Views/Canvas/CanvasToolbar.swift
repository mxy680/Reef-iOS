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

    static let diagramMin: CGFloat = 4
    static let diagramMax: CGFloat = 48
    static let diagramDefault: CGFloat = 37
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
    @Binding var diagramWidth: CGFloat
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
    var isDocumentAIReady: Bool = true
    var onAddPageAfterCurrent: () -> Void = {}
    var onAddPageToEnd: () -> Void = {}
    var onDeleteCurrentPage: () -> Void = {}
    var onClearCurrentPage: () -> Void = {}

    @State private var contextualToolbarHidden: Bool = false
    @State private var backgroundModeSelected: Bool = false
    @State private var aiModeSelected: Bool = false
    @State private var documentOperationsSelected: Bool = false

    private var toolHasContextualMenu: Bool {
        switch selectedTool {
        case .pen, .highlighter, .eraser, .diagram:
            return true
        case .lasso:
            return false  // Use Apple's default popup menu
        }
    }

    private var showToolContextualToolbar: Bool {
        guard !backgroundModeSelected else { return false }
        switch selectedTool {
        case .pen, .highlighter, .eraser, .diagram:
            return !contextualToolbarHidden
        case .lasso:
            return false  // Use Apple's default popup menu
        }
    }

    private var showBackgroundModeToolbar: Bool {
        backgroundModeSelected
    }

    private var showAIToolbar: Bool {
        aiModeSelected
    }

    private var showDocumentOperationsToolbar: Bool {
        documentOperationsSelected
    }

    private func selectTool(_ tool: CanvasTool) {
        // Deselect other modes when selecting a drawing tool
        backgroundModeSelected = false
        aiModeSelected = false
        documentOperationsSelected = false

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
            // Select background mode, hide other toolbars
            backgroundModeSelected = true
            contextualToolbarHidden = true
            aiModeSelected = false
            documentOperationsSelected = false
        }
    }

    private func selectAIMode() {
        if aiModeSelected {
            // Toggle off if already selected
            aiModeSelected = false
        } else {
            // Select AI mode, hide other contextual toolbars
            aiModeSelected = true
            contextualToolbarHidden = true
            backgroundModeSelected = false
            documentOperationsSelected = false
        }
    }

    private func selectDocumentOperations() {
        if documentOperationsSelected {
            // Toggle off if already selected
            documentOperationsSelected = false
        } else {
            // Select document operations, hide other toolbars
            documentOperationsSelected = true
            contextualToolbarHidden = true
            backgroundModeSelected = false
            aiModeSelected = false
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
                    diagramWidth: $diagramWidth,
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

            // AI toolbar tier
            if showAIToolbar {
                AIToolbar(
                    colorScheme: colorScheme,
                    onClose: { aiModeSelected = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Document operations toolbar tier
            if showDocumentOperationsToolbar {
                DocumentOperationsToolbar(
                    colorScheme: colorScheme,
                    onAddPageAfterCurrent: onAddPageAfterCurrent,
                    onAddPageToEnd: onAddPageToEnd,
                    onDeleteCurrentPage: onDeleteCurrentPage,
                    onClearCurrentPage: onClearCurrentPage,
                    onClose: { documentOperationsSelected = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main toolbar
            mainToolbar
        }
        .animation(.easeOut(duration: 0.2), value: showToolContextualToolbar)
        .animation(.easeOut(duration: 0.2), value: showBackgroundModeToolbar)
        .animation(.easeOut(duration: 0.2), value: showAIToolbar)
        .animation(.easeOut(duration: 0.2), value: showDocumentOperationsToolbar)
        .animation(.easeOut(duration: 0.2), value: selectedTool)
        .animation(.easeOut(duration: 0.2), value: contextualToolbarHidden)
        .animation(.easeOut(duration: 0.2), value: backgroundModeSelected)
        .animation(.easeOut(duration: 0.2), value: aiModeSelected)
        .animation(.easeOut(duration: 0.2), value: documentOperationsSelected)
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
                isSelected: selectedTool == .pen && !backgroundModeSelected,
                colorScheme: colorScheme,
                action: { selectTool(.pen) }
            )

            ToolbarButton(
                icon: "skew",
                isSelected: selectedTool == .diagram && !backgroundModeSelected,
                colorScheme: colorScheme,
                action: { selectTool(.diagram) }
            )

            ToolbarButton(
                icon: "highlighter",
                isSelected: selectedTool == .highlighter && !backgroundModeSelected,
                colorScheme: colorScheme,
                action: { selectTool(.highlighter) }
            )

            ToolbarButton(
                icon: "eraser.fill",
                isSelected: selectedTool == .eraser && !backgroundModeSelected,
                colorScheme: colorScheme,
                action: { selectTool(.eraser) }
            )

            ToolbarButton(
                icon: "lasso",
                isSelected: selectedTool == .lasso && !backgroundModeSelected,
                colorScheme: colorScheme,
                action: { selectTool(.lasso) }
            )

            // Background mode button
            ToolbarButton(
                icon: "squareshape.split.3x3",
                isSelected: backgroundModeSelected,
                colorScheme: colorScheme,
                action: selectBackgroundMode
            )

            // Document operations button
            ToolbarButton(
                icon: "doc.badge.plus",
                isSelected: documentOperationsSelected,
                colorScheme: colorScheme,
                action: selectDocumentOperations
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
                isSelected: aiModeSelected,
                isDisabled: !isDocumentAIReady,
                showProcessingIndicator: !isDocumentAIReady,
                colorScheme: colorScheme,
                action: selectAIMode
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
    var showProcessingIndicator: Bool = false
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var processingPulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
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

                // Yellow pulsing indicator when processing
                if showProcessingIndicator {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .scaleEffect(processingPulseScale)
                        .shadow(color: Color.yellow.opacity(0.5), radius: 2)
                        .offset(x: -4, y: 4)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                            ) {
                                processingPulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            processingPulseScale = 1.0
                        }
                }
            }
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

// MARK: - AI Toolbar

private struct AIToolbar: View {
    let colorScheme: ColorScheme
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Ask (Push to Talk) button
            AIToolbarButton(
                icon: "mic.fill",
                label: "Ask",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Simplify button
            AIToolbarButton(
                icon: "list.bullet",
                label: "Simplify",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Hint button
            AIToolbarButton(
                icon: "lightbulb.fill",
                label: "Hint",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Improve button
            AIToolbarButton(
                icon: "wand.and.stars",
                label: "Improve",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Check button
            AIToolbarButton(
                icon: "checkmark.circle.fill",
                label: "Check",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Show Error button
            AIToolbarButton(
                icon: "exclamationmark.triangle.fill",
                label: "Show",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Stuck button
            AIToolbarButton(
                icon: "hand.raised.fill",
                label: "Stuck",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

            // Recap button
            AIToolbarButton(
                icon: "arrow.counterclockwise",
                label: "Recap",
                colorScheme: colorScheme,
                action: { /* No functionality yet */ }
            )

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

// MARK: - AI Toolbar Button

private struct AIToolbarButton: View {
    let icon: String
    let label: String
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Color.adaptiveText(for: colorScheme))
            .frame(width: 52, height: 40)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Operations Toolbar

private struct DocumentOperationsToolbar: View {
    let colorScheme: ColorScheme
    let onAddPageAfterCurrent: () -> Void
    let onAddPageToEnd: () -> Void
    let onDeleteCurrentPage: () -> Void
    let onClearCurrentPage: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Add page after current
            Button {
                onAddPageAfterCurrent()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Insert After")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // Add page to end
            Button {
                onAddPageToEnd()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "doc.fill.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Add to End")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // Clear current page
            Button {
                onClearCurrentPage()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "eraser.line.dashed")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Clear Page")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // Delete current page
            Button {
                onDeleteCurrentPage()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Delete Page")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.red.opacity(0.8))
                .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)

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
            diagramWidth: .constant(StrokeWidthRange.diagramDefault),
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
            onToggleDarkMode: {},
            isDocumentAIReady: false  // Shows processing indicator in preview
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
