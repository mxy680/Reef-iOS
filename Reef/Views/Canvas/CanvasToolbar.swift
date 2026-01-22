//
//  CanvasToolbar.swift
//  Reef
//
//  Top toolbar for the annotation canvas with drawing tools

import SwiftUI

struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var selectedColor: Color
    @Binding var penSize: ToolSize
    @Binding var highlighterSize: ToolSize
    @Binding var eraserSize: ToolSize
    @Binding var isShowingColorPicker: Bool
    @Binding var isShowingOverflowMenu: Bool

    let canUndo: Bool
    let canRedo: Bool
    let isBlankCanvas: Bool
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onAddPage: (() -> Void)?
    let colorScheme: ColorScheme

    @State private var showingSizePopover: CanvasTool?

    var body: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 8)

            // Tool buttons group
            HStack(spacing: 4) {
                ToolButton(
                    tool: .pen,
                    selectedTool: $selectedTool,
                    showingSizePopover: $showingSizePopover,
                    currentSize: penSize,
                    colorScheme: colorScheme
                )

                ToolButton(
                    tool: .highlighter,
                    selectedTool: $selectedTool,
                    showingSizePopover: $showingSizePopover,
                    currentSize: highlighterSize,
                    colorScheme: colorScheme
                )

                ToolButton(
                    tool: .eraser,
                    selectedTool: $selectedTool,
                    showingSizePopover: $showingSizePopover,
                    currentSize: eraserSize,
                    colorScheme: colorScheme
                )
            }

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 8)

            // Undo/Redo
            HStack(spacing: 4) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(canUndo ? Color.adaptiveText(for: colorScheme) : Color.adaptiveText(for: colorScheme).opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(canRedo ? Color.adaptiveText(for: colorScheme) : Color.adaptiveText(for: colorScheme).opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!canRedo)
            }

            Spacer()

            // Color swatch
            Button {
                isShowingColorPicker.toggle()
            } label: {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.adaptiveText(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )
                    .padding(8)
            }
            .buttonStyle(.plain)

            // Add Page button (only for blank canvases)
            if isBlankCanvas, let onAddPage = onAddPage {
                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 8)

                Button(action: onAddPage) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.adaptiveText(for: colorScheme))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 8)

            // Overflow menu
            Button {
                isShowingOverflowMenu.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(colorScheme == .dark ? Color.deepOcean : Color.sageMist)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.adaptiveText(for: colorScheme).opacity(0.15))
                .frame(height: 1)
        }
        .overlay {
            if let tool = showingSizePopover {
                SizePopover(
                    tool: tool,
                    size: bindingForTool(tool),
                    isShowing: Binding(
                        get: { showingSizePopover != nil },
                        set: { if !$0 { showingSizePopover = nil } }
                    ),
                    colorScheme: colorScheme
                )
            }
        }
    }

    private func bindingForTool(_ tool: CanvasTool) -> Binding<ToolSize> {
        switch tool {
        case .pen: return $penSize
        case .highlighter: return $highlighterSize
        case .eraser: return $eraserSize
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: CanvasTool
    @Binding var selectedTool: CanvasTool
    @Binding var showingSizePopover: CanvasTool?
    let currentSize: ToolSize
    let colorScheme: ColorScheme

    @State private var isLongPressing = false

    private var isSelected: Bool {
        selectedTool == tool
    }

    var body: some View {
        Button {
            selectedTool = tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? Color.vibrantTeal : Color.adaptiveText(for: colorScheme))

                // Size indicator dot
                Circle()
                    .fill(isSelected ? Color.vibrantTeal : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.vibrantTeal.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    showingSizePopover = tool
                }
        )
    }
}

// MARK: - Size Popover

struct SizePopover: View {
    let tool: CanvasTool
    @Binding var size: ToolSize
    @Binding var isShowing: Bool
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Dismiss backdrop
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            VStack(spacing: 8) {
                Text("\(tool.rawValue.capitalized) Size")
                    .font(.quicksand(13, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))

                ForEach(ToolSize.allCases, id: \.self) { toolSize in
                    Button {
                        size = toolSize
                        isShowing = false
                    } label: {
                        HStack {
                            // Size preview
                            Circle()
                                .fill(Color.adaptiveText(for: colorScheme))
                                .frame(width: sizePreviewWidth(for: toolSize), height: sizePreviewWidth(for: toolSize))
                                .frame(width: 30, height: 20)

                            Text(toolSize.displayName)
                                .font(.quicksand(14, weight: size == toolSize ? .semiBold : .regular))
                                .foregroundColor(Color.adaptiveText(for: colorScheme))

                            Spacer()

                            if size == toolSize {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.vibrantTeal)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(size == toolSize ? Color.vibrantTeal.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(colorScheme == .dark ? Color.deepOcean : Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
            .frame(width: 160)
            .position(x: toolPositionX, y: 100)
        }
    }

    private var toolPositionX: CGFloat {
        switch tool {
        case .pen: return 100
        case .highlighter: return 148
        case .eraser: return 196
        }
    }

    private func sizePreviewWidth(for toolSize: ToolSize) -> CGFloat {
        switch tool {
        case .pen:
            return toolSize.penWidth * 2
        case .highlighter:
            return min(toolSize.highlighterWidth / 2, 12)
        case .eraser:
            return min(toolSize.eraserWidth / 3, 12)
        }
    }
}
