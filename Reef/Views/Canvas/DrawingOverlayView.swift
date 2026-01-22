//
//  DrawingOverlayView.swift
//  Reef
//
//  UIViewRepresentable wrapper for PencilKit's PKCanvasView

import SwiftUI
import PencilKit

struct DrawingOverlayView: UIViewRepresentable {
    let pageIndex: Int
    let selectedTool: CanvasTool
    let selectedColor: Color
    let toolSize: ToolSize
    @Binding var drawing: PKDrawing
    let onDrawingChanged: ((PKDrawing) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator

        // Allow finger and pencil drawing
        canvasView.drawingPolicy = .anyInput

        // Configure initial tool
        canvasView.tool = makeTool()

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Update tool when selection changes
        canvasView.tool = makeTool()

        // Update drawing if it changed externally (e.g., undo/redo)
        if canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, onDrawingChanged: onDrawingChanged)
    }

    private func makeTool() -> PKTool {
        let uiColor = UIColor(selectedColor)

        switch selectedTool {
        case .pen:
            return PKInkingTool(.pen, color: uiColor, width: toolSize.penWidth)
        case .highlighter:
            // Highlighter uses 40% opacity
            let highlighterColor = uiColor.withAlphaComponent(0.4)
            return PKInkingTool(.marker, color: highlighterColor, width: toolSize.highlighterWidth)
        case .eraser:
            return PKEraserTool(.bitmap, width: toolSize.eraserWidth)
        }
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        let onDrawingChanged: ((PKDrawing) -> Void)?

        init(drawing: Binding<PKDrawing>, onDrawingChanged: ((PKDrawing) -> Void)?) {
            self._drawing = drawing
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.drawing = canvasView.drawing
                self?.onDrawingChanged?(canvasView.drawing)
            }
        }
    }
}

