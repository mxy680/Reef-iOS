//
//  CanvasToolbar.swift
//  Reef
//
//  GoodNotes 6-style top-of-screen toolbar with popover-based tool options
//

import SwiftUI

// MARK: - Tool Types

enum CanvasTool: Equatable {
    case pen
    case diagram
    case highlighter
    case eraser
    case lasso
    case textBox
    case pan
}

extension CanvasTool {
    var hasSecondaryOptions: Bool {
        switch self {
        case .pen, .highlighter, .eraser: return true
        case .diagram, .textBox, .lasso, .pan: return false
        }
    }
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
        case .normal: return "doc"
        case .grid: return "squareshape.split.3x3"
        case .dotted: return "circle.grid.3x3.fill"
        case .lined: return "text.justify.left"
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

    static let eraserSmall: CGFloat = 12
    static let eraserMedium: CGFloat = 24
    static let eraserLarge: CGFloat = 48
    static let eraserDefault: CGFloat = 24


}

// MARK: - View Mode

enum CanvasViewMode: String, CaseIterable {
    case document
    case assignment

    var displayName: String {
        switch self {
        case .document: return "Doc"
        case .assignment: return "Assign"
        }
    }

    var iconName: String {
        switch self {
        case .document: return "doc.text"
        case .assignment: return "list.number"
        }
    }
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
    let onHomePressed: () -> Void
    var onAIActionSelected: (String) -> Void = { _ in }
    let onToggleDarkMode: () -> Void
    var isDocumentAIReady: Bool = true
    var isServerConnected: Bool = true
    var onAddPageAfterCurrent: () -> Void = {}
    var onAddPageToEnd: () -> Void = {}
    var onDeleteCurrentPage: () -> Void = {}
    var onDeleteLastPage: () -> Void = {}
    var onClearCurrentPage: () -> Void = {}
    var onExportPDF: () -> Void = {}
    var pageCount: Int = 1

    // Undo/Redo
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onUndo: () -> Void = {}
    var onRedo: () -> Void = {}

    // Assignment mode properties
    var isAssignmentEnabled: Bool = false
    @Binding var viewMode: CanvasViewMode
    var currentQuestionIndex: Int = 0
    var totalQuestions: Int = 0
    var onPreviousQuestion: () -> Void = {}
    var onNextQuestion: () -> Void = {}
    var onJumpToQuestion: (Int) -> Void = { _ in }
    var isAssignmentProcessing: Bool = false
    var isRecording: Bool = false

    // Ruler toggle
    var isRulerActive: Bool = false
    var onToggleRuler: () -> Void = {}

    // Text box tool options
    @Binding var textSize: CGFloat
    @Binding var textColor: Color

    // Debug sidebar
    @Binding var showDebugSidebar: Bool

    // Secondary toolbar state (inline tool options)
    @State private var showSecondaryToolbar: Bool = false
    @State private var showBackgroundOptions: Bool = false

    // Non-drawing popover state
    @State private var showDocOpsPopover: Bool = false
    @State private var showAIPopover: Bool = false
    @State private var showPageOpsPopover: Bool = false

    private var paginationEnabled: Bool {
        viewMode == .assignment && totalQuestions > 0 && !isAssignmentProcessing
    }

    private var isAssignmentReady: Bool {
        isAssignmentEnabled && totalQuestions > 0 && !isAssignmentProcessing
    }

    private func closeAllPopovers() {
        showDocOpsPopover = false
        showAIPopover = false
        showPageOpsPopover = false
    }

    private func selectTool(_ tool: CanvasTool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            closeAllPopovers()
            showBackgroundOptions = false
            if selectedTool == tool {
                // Already selected — toggle secondary toolbar
                showSecondaryToolbar.toggle()
            } else {
                selectedTool = tool
                showSecondaryToolbar = tool.hasSecondaryOptions
            }
        }
    }

    private func toggleBackgroundOptions() {
        withAnimation(.easeInOut(duration: 0.2)) {
            closeAllPopovers()
            showSecondaryToolbar = false
            showBackgroundOptions.toggle()
        }
    }

    private func toggleNonDrawingPopover(_ popover: inout Bool) {
        if popover {
            popover = false
        } else {
            closeAllPopovers()
            withAnimation(.easeInOut(duration: 0.2)) {
                showSecondaryToolbar = false
                showBackgroundOptions = false
            }
            popover = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Problem tab bar (only when assignment enabled)
            if isAssignmentEnabled {
                problemTabBar
            }

            HStack(spacing: 0) {
                // LEFT SECTION: Undo, Redo (+ Home when not assignment)
                leftSection

                toolbarDivider

                Spacer(minLength: 0)

                // CENTER SECTION: Drawing tools
                centerSection

                toolbarDivider

                // CANVAS UTILITIES: Ruler, Background, Pages
                canvasUtilitiesSection

                toolbarDivider

                // AI SECTION: Inline AI action buttons
                aiSection

                Spacer(minLength: 0)

                // RIGHT SECTION: BG, Doc Ops, Dark
                rightSection
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(toolbarBackground)

            // Bottom separator line
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            secondaryToolbar
                .offset(y: 56)
        }
        .zIndex(1)
        .background(
            (isAssignmentEnabled ? tabStripBackground : toolbarBackground)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Problem Tab Bar

    private var assignmentModeBinding: Binding<Bool> {
        Binding(
            get: { viewMode == .assignment },
            set: { viewMode = $0 ? .assignment : .document }
        )
    }

    private var toolbarBackground: Color {
        colorScheme == .dark ? .toolbarDark : .deepTeal
    }

    private var tabStripBackground: Color {
        colorScheme == .dark ? .tabStripDark : Color(red: 0.28, green: 0.53, blue: 0.52)
    }

    private var tabSurface: Color {
        colorScheme == .dark ? .toolbarDark : .deepTeal
    }

    private var problemTabBar: some View {
        ZStack(alignment: .bottom) {
            // Recessed tab strip background
            tabStripBackground

            // Left-aligned scrollable Chrome-style tabs
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<totalQuestions, id: \.self) { index in
                            let isSelected = index == currentQuestionIndex

                            Button {
                                onJumpToQuestion(index)
                            } label: {
                                Text("Q\(index + 1)")
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(
                                        isSelected
                                            ? .white
                                            : Color.white.opacity(0.55)
                                    )
                                    .frame(minWidth: 42, minHeight: 30)
                                    .padding(.horizontal, 4)
                                    .background(
                                        isSelected
                                            ? tabSurface
                                            : Color.clear
                                    )
                                    .clipShape(ChromeTabShape())
                                    .overlay(
                                        isSelected
                                            ? ChromeTabShape()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                            : nil
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(index)

                            // Separator between unselected tabs
                            if index < totalQuestions - 1 && !isSelected && index + 1 != currentQuestionIndex {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 1, height: 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
                }
                .padding(.leading, 48)
                .padding(.trailing, 150)
                .onChange(of: currentQuestionIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            // Pinned edges
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Home button
                    Button(action: onHomePressed) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)

                }
                .background(tabStripBackground)

                Spacer()

                // Assignment mode toggle
                HStack(spacing: 6) {
                    Text("Tutor Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAssignmentEnabled ? .white : (colorScheme == .dark ? .white.opacity(0.5) : .deepTeal))
                    Toggle("", isOn: assignmentModeBinding)
                        .toggleStyle(TutorToggleStyle())
                        .labelsHidden()
                        .disabled(isAssignmentProcessing)
                }
                .padding(.trailing, 10)
                .padding(.leading, 4)
                .frame(height: 40)
                .background(tabStripBackground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    // MARK: - Left Section

    private var leftSection: some View {
        HStack(spacing: 0) {
            // Back button (only when NOT in assignment mode — it's in the tab bar otherwise)
            if !isAssignmentEnabled {
                ToolbarButton(
                    icon: "chevron.left",
                    isSelected: false,
                    colorScheme: colorScheme,
                    action: onHomePressed
                )
            }

            // Undo button
            ToolbarButton(
                icon: "arrow.uturn.backward",
                isSelected: false,
                isDisabled: !canUndo,
                colorScheme: colorScheme,
                action: onUndo
            )

            // Redo button
            ToolbarButton(
                icon: "arrow.uturn.forward",
                isSelected: false,
                isDisabled: !canRedo,
                colorScheme: colorScheme,
                action: onRedo
            )
        }
    }

    // MARK: - Center Section

    private var centerSection: some View {
        HStack(spacing: 0) {
            // --- Drawing tools ---

            // Pen
            DrawingToolButton(
                icon: "pencil.tip",
                isSelected: selectedTool == .pen,
                colorDot: selectedPenColor,
                showColorDot: true,
                colorScheme: colorScheme,
                action: { selectTool(.pen) }
            )

            // Diagram
            ToolbarButton(
                icon: "scribble.variable",
                isSelected: selectedTool == .diagram,
                colorScheme: colorScheme,
                action: { selectTool(.diagram) }
            )

            // --- Edit tools ---

            // Eraser
            DrawingToolButton(
                icon: "eraser.fill",
                isSelected: selectedTool == .eraser,
                colorDot: .clear,
                showColorDot: false,
                colorScheme: colorScheme,
                action: { selectTool(.eraser) }
            )

            // Lasso
            ToolbarButton(
                icon: "lasso",
                isSelected: selectedTool == .lasso,
                colorScheme: colorScheme,
                action: { selectTool(.lasso) }
            )

            // Pan (scroll/zoom) — useful in simulator where finger = draw
            ToolbarButton(
                icon: "hand.draw.fill",
                isSelected: selectedTool == .pan,
                colorScheme: colorScheme,
                action: { selectTool(.pan) }
            )
        }
    }

    // MARK: - Canvas Utilities Section

    private var canvasUtilitiesSection: some View {
        HStack(spacing: 0) {
            // Ruler toggle
            ToolbarButton(
                icon: "pencil.and.ruler.fill",
                isSelected: isRulerActive,
                colorScheme: colorScheme,
                action: onToggleRuler
            )

            // Background mode (grid/dots/lines)
            ToolbarButton(
                icon: "document.badge.gearshape.fill",
                isSelected: showBackgroundOptions,
                colorScheme: colorScheme,
                action: toggleBackgroundOptions
            )

            // Page operations
            ToolbarButton(
                icon: "doc.fill.badge.plus",
                isSelected: showPageOpsPopover,
                colorScheme: colorScheme,
                action: { toggleNonDrawingPopover(&showPageOpsPopover) }
            )
            .popover(isPresented: $showPageOpsPopover) {
                HStack(spacing: 0) {
                    Button {
                        showPageOpsPopover = false
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

                    Rectangle()
                        .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 4)

                    Button {
                        showPageOpsPopover = false
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

                    Rectangle()
                        .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 4)

                    Button {
                        showPageOpsPopover = false
                        onDeleteCurrentPage()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 24, height: 24)
                            Text("Delete Current")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 72, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageCount <= 1)
                    .opacity(pageCount <= 1 ? 0.4 : 1.0)

                    Rectangle()
                        .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 4)

                    Button {
                        showPageOpsPopover = false
                        onDeleteLastPage()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 24, height: 24)
                            Text("Delete Last")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 72, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(pageCount <= 1)
                    .opacity(pageCount <= 1 ? 0.4 : 1.0)
                }
                .padding(12)
                .reefPopoverStyle(colorScheme: colorScheme)
            }
        }
    }

    // MARK: - Secondary Toolbar (Floating Tool Options)

    private var showFloatingToolbar: Bool {
        (showSecondaryToolbar && selectedTool.hasSecondaryOptions) || showBackgroundOptions
    }

    @ViewBuilder
    private var secondaryToolbar: some View {
        if showFloatingToolbar {
            HStack(spacing: 0) {
                if showBackgroundOptions {
                    BackgroundModePopoverContent(
                        canvasBackgroundMode: $canvasBackgroundMode,
                        canvasBackgroundOpacity: $canvasBackgroundOpacity,
                        canvasBackgroundSpacing: $canvasBackgroundSpacing,
                        colorScheme: colorScheme
                    )
                } else {
                    switch selectedTool {
                    case .pen:
                        PenOptionsView(
                            penWidth: $penWidth,
                            selectedPenColor: $selectedPenColor,
                            customPenColors: $customPenColors,
                            colorScheme: colorScheme
                        )
                    case .highlighter:
                        HighlighterOptionsView(
                            highlighterWidth: $highlighterWidth,
                            selectedHighlighterColor: $selectedHighlighterColor,
                            customHighlighterColors: $customHighlighterColors,
                            colorScheme: colorScheme
                        )
                    case .eraser:
                        EraserOptionsView(
                            eraserSize: $eraserSize,
                            eraserType: $eraserType,
                            colorScheme: colorScheme,
                            onClearPage: onClearCurrentPage
                        )
                    case .diagram, .textBox, .lasso, .pan:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorScheme == .dark ? Color.warmDark : Color.blushWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }
    }

    // MARK: - AI Section

    private var aiDisabled: Bool {
        !isServerConnected || !isDocumentAIReady || (isAssignmentEnabled && !isAssignmentReady)
    }

    @ViewBuilder
    private var aiSection: some View {
        if isAssignmentEnabled {
            // Mic
            ToolbarButton(
                icon: isRecording ? "mic.fill" : "mic.fill",
                isSelected: isRecording,
                isDisabled: aiDisabled,
                showProcessingIndicator: isRecording || !isServerConnected || !isDocumentAIReady || isAssignmentProcessing,
                processingIndicatorColor: isRecording ? .red : (!isServerConnected ? .orange : (isAssignmentProcessing ? .blue : .yellow)),
                colorScheme: colorScheme,
                action: { onAIActionSelected("ask") }
            )

            // More AI actions
            ToolbarButton(
                icon: "ellipsis.circle.fill",
                isSelected: showAIPopover,
                isDisabled: aiDisabled,
                colorScheme: colorScheme,
                action: { toggleNonDrawingPopover(&showAIPopover) }
            )
            .popover(isPresented: $showAIPopover) {
                AIActionsPopoverContent(
                    colorScheme: colorScheme,
                    onActionSelected: { action in
                        showAIPopover = false
                        onAIActionSelected(action)
                    }
                )
                .reefPopoverStyle(colorScheme: colorScheme)
            }
        }
    }

    // MARK: - Right Section

    private var rightSection: some View {
        HStack(spacing: 0) {
            // Debug sidebar toggle
            ToolbarButton(
                icon: "sidebar.trailing",
                isSelected: showDebugSidebar,
                colorScheme: colorScheme,
                action: { showDebugSidebar.toggle() }
            )

            // Export PDF
            ToolbarButton(
                icon: "square.and.arrow.up.fill",
                isSelected: false,
                colorScheme: colorScheme,
                action: onExportPDF
            )
            .offset(y: -1)

            // Dark mode toggle
            ToolbarButton(
                icon: colorScheme == .dark ? "sun.max.fill" : "moon.fill",
                isSelected: false,
                colorScheme: colorScheme,
                action: onToggleDarkMode
            )
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 6)
    }
}

// MARK: - Drawing Tool Button (with color dot indicator)

private struct DrawingToolButton: View {
    let icon: String
    let isSelected: Bool
    let colorDot: Color
    let showColorDot: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    isSelected ?
                        Color.white.opacity(0.25) :
                        Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        }
        return Color.white.opacity(0.9)
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let isSelected: Bool
    var isDisabled: Bool = false
    var showProcessingIndicator: Bool = false
    var processingIndicatorColor: Color = .yellow
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var processingPulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(foregroundColor)
                    .frame(width: 36, height: 36, alignment: .center)
                    .background(
                        isSelected ?
                            Color.white.opacity(0.25) :
                            Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Pulsing indicator when processing
                if showProcessingIndicator {
                    Circle()
                        .fill(processingIndicatorColor)
                        .frame(width: 7, height: 7)
                        .scaleEffect(processingPulseScale)
                        .shadow(color: processingIndicatorColor.opacity(0.5), radius: 2)
                        .offset(x: -2, y: 2)
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
        .frame(width: 36, height: 36)
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return Color.white.opacity(0.35)
        }
        if isSelected {
            return .white
        }
        return Color.white.opacity(0.9)
    }
}

// MARK: - Background Mode Popover Content

private struct BackgroundModePopoverContent: View {
    @Binding var canvasBackgroundMode: CanvasBackgroundMode
    @Binding var canvasBackgroundOpacity: CGFloat
    @Binding var canvasBackgroundSpacing: CGFloat
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CanvasBackgroundMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        canvasBackgroundMode = mode
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 24, height: 24)
                        Text(mode.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(canvasBackgroundMode == mode ? .deepTeal : Color.adaptiveText(for: colorScheme))
                    .frame(width: 56, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canvasBackgroundMode == mode ? Color.deepTeal.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            if canvasBackgroundMode != .normal {
                Rectangle()
                    .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 8)

                // Opacity slider
                HStack(spacing: 4) {
                    Image(systemName: "sun.min")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))

                    Slider(value: $canvasBackgroundOpacity, in: 0.05...0.5)
                        .accentColor(.deepTeal)
                        .frame(width: 60)

                    Image(systemName: "sun.max")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                }

                Rectangle()
                    .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 6)

                // Spacing slider
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))

                    Slider(value: $canvasBackgroundSpacing, in: 24...80)
                        .accentColor(.deepTeal)
                        .frame(width: 60)

                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
    }
}

// MARK: - AI Actions Popover Content

private struct AIActionsPopoverContent: View {
    let colorScheme: ColorScheme
    let onActionSelected: (String) -> Void

    private struct AIActionItem: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private struct AIActionSection: Identifiable {
        let id: String
        let title: String
        let items: [AIActionItem]
    }

    private var sections: [AIActionSection] {
        [
            AIActionSection(id: "quick", title: "QUICK ACTIONS", items: [
                AIActionItem(id: "hint", icon: "lightbulb.fill", label: "Hint"),
                AIActionItem(id: "check", icon: "checkmark.circle.fill", label: "Check"),
            ]),
            AIActionSection(id: "help", title: "HELP ME", items: [
                AIActionItem(id: "simplify", icon: "list.bullet", label: "Simplify"),
                AIActionItem(id: "improve", icon: "wand.and.stars", label: "Improve"),
                AIActionItem(id: "stuck", icon: "hand.raised.fill", label: "Stuck"),
                AIActionItem(id: "show", icon: "exclamationmark.triangle.fill", label: "Show Answer"),
            ]),
            AIActionSection(id: "understand", title: "UNDERSTAND", items: [
                AIActionItem(id: "why", icon: "questionmark.bubble", label: "Why?"),
                AIActionItem(id: "define", icon: "text.book.closed", label: "Define"),
                AIActionItem(id: "step_by_step", icon: "list.number", label: "Step-by-Step"),
            ]),
            AIActionSection(id: "review", title: "REVIEW", items: [
                AIActionItem(id: "recap", icon: "arrow.clockwise", label: "Recap"),
                AIActionItem(id: "find_error", icon: "magnifyingglass", label: "Find Error"),
                AIActionItem(id: "compare", icon: "arrow.left.arrow.right", label: "Compare"),
                AIActionItem(id: "organize", icon: "text.justify.left", label: "Organize"),
                AIActionItem(id: "summarize", icon: "doc.plaintext", label: "Summarize"),
            ]),
            AIActionSection(id: "practice", title: "PRACTICE", items: [
                AIActionItem(id: "similar", icon: "plus.square.on.square", label: "Similar Problem"),
                AIActionItem(id: "quiz", icon: "brain.head.profile", label: "Quiz Me"),
                AIActionItem(id: "flashcard", icon: "rectangle.on.rectangle.angled", label: "Flashcard"),
            ]),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    if sectionIndex > 0 {
                        Rectangle()
                            .fill(Color.adaptiveText(for: colorScheme).opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }

                    // Section header
                    HStack {
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme).opacity(0.45))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, sectionIndex == 0 ? 8 : 4)
                    .padding(.bottom, 2)

                    // Section items
                    ForEach(section.items) { action in
                        Button {
                            onActionSelected(action.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 24, height: 24)
                                Text(action.label)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(Color.adaptiveText(for: colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: 8)
            }
        }
        .frame(width: 220)
        .frame(maxHeight: 400)
    }
}

// MARK: - Document Operations Popover Content

private struct DocumentOperationsPopoverContent: View {
    let colorScheme: ColorScheme
    let onAddPageAfterCurrent: () -> Void
    let onAddPageToEnd: () -> Void
    let onDeleteCurrentPage: () -> Void
    let onClearCurrentPage: () -> Void
    let onExportPDF: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

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

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

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

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            Button {
                onExportPDF()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Export PDF")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.adaptiveText(for: colorScheme))
                .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.2))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

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
        }
        .frame(height: 48)
    }
}

// MARK: - Chrome Tab Shape

private struct ChromeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let curve: CGFloat = 8
        var path = Path()

        // Start at bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Curve up to top-left
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + curve, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        // Straight across top
        path.addLine(to: CGPoint(x: rect.maxX - curve, y: rect.minY))
        // Curve down to bottom-right
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        // Close along the bottom
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack {
        CanvasToolbar(
            selectedTool: .constant(.pen),
            selectedPenColor: .constant(.charcoal),
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
            onHomePressed: {},
            onToggleDarkMode: {},
            isDocumentAIReady: false,
            canUndo: true,
            canRedo: false,
            isAssignmentEnabled: true,
            viewMode: .constant(.document),
            currentQuestionIndex: 2,
            totalQuestions: 12,
            textSize: .constant(16),
            textColor: .constant(.black),
            showDebugSidebar: .constant(false)
        )
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

// MARK: - Reef Popover Style

private struct ReefPopoverStyle: ViewModifier {
    let colorScheme: ColorScheme

    private var cardBg: Color {
        colorScheme == .dark ? .warmDarkCard : .blushWhite
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : .charcoal
    }

    func body(content: Content) -> some View {
        content
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .presentationCompactAdaptation(.popover)
            .presentationBackground(cardBg)
    }
}

private extension View {
    func reefPopoverStyle(colorScheme: ColorScheme) -> some View {
        modifier(ReefPopoverStyle(colorScheme: colorScheme))
    }
}

// MARK: - Tutor Toggle Style

private struct TutorToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let trackWidth: CGFloat = 36
        let trackHeight: CGFloat = 20
        let knobSize: CGFloat = 16
        let knobPadding: CGFloat = 2

        let onColor = colorScheme == .dark ? Color.brightTealDark : Color.deepTeal
        let offColor = colorScheme == .dark ? Color.warmWhite.opacity(0.12) : Color.charcoal.opacity(0.12)
        let borderColor = colorScheme == .dark ? Color.warmWhite.opacity(0.25) : Color.charcoal.opacity(0.25)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? onColor : offColor)
                    .overlay(
                        Capsule()
                            .strokeBorder(configuration.isOn ? Color.clear : borderColor, lineWidth: 1)
                    )
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(knobPadding)
            }
        }
        .buttonStyle(.plain)
    }
}
