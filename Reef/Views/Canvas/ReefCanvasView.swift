//
//  ReefCanvasView.swift
//  Reef
//
//  Custom PKCanvasView subclass with selection and clipboard support
//

import PencilKit
import UIKit

class ReefCanvasView: PKCanvasView {

    // MARK: - Selection Tracking

    /// Callback fired when selection state changes (has selection or not)
    var onSelectionChanged: ((Bool) -> Void)?

    /// Whether there are currently selected strokes
    private(set) var hasSelection: Bool = false {
        didSet {
            if hasSelection != oldValue {
                onSelectionChanged?(hasSelection)
            }
        }
    }

    /// The currently selected strokes (if any)
    private var selectedStrokeIndices: Set<Int> = []

    // MARK: - Clipboard Operations

    /// Clipboard type identifier for PKDrawing data
    private static let drawingPasteboardType = "com.reef.pkdrawing"

    /// Check if there's pasteable content on the clipboard
    var canPaste: Bool {
        return UIPasteboard.general.hasStrings ||
               UIPasteboard.general.data(forPasteboardType: Self.drawingPasteboardType) != nil
    }

    /// Copy selected strokes to clipboard
    func copySelection() {
        guard hasSelection else { return }

        // Get selected strokes from the first responder chain
        // PKCanvasView uses UIPasteboard internally for copy operations
        // We trigger the standard copy action
        if let undoManager = undoManager {
            // Use the standard copy mechanism
            UIApplication.shared.sendAction(#selector(UIResponder.copy(_:)), to: nil, from: self, for: nil)
        }
    }

    /// Cut selected strokes (copy + delete)
    func cutSelection() {
        guard hasSelection else { return }

        // Use the standard cut mechanism
        UIApplication.shared.sendAction(#selector(UIResponder.cut(_:)), to: nil, from: self, for: nil)

        // Selection is now gone
        hasSelection = false
    }

    /// Delete selected strokes
    func deleteSelection() {
        guard hasSelection else { return }

        // Use the standard delete mechanism
        UIApplication.shared.sendAction(#selector(UIResponder.delete(_:)), to: nil, from: self, for: nil)

        // Selection is now gone
        hasSelection = false
    }

    /// Paste strokes from clipboard
    func pasteFromClipboard() {
        // Use the standard paste mechanism
        UIApplication.shared.sendAction(#selector(UIResponder.paste(_:)), to: nil, from: self, for: nil)
    }

    // MARK: - Selection Detection via First Responder

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let canPerform = super.canPerformAction(action, withSender: sender)

        // Track selection state based on what actions are available
        // When strokes are selected, copy/cut/delete become available
        if action == #selector(UIResponder.copy(_:)) ||
           action == #selector(UIResponder.cut(_:)) ||
           action == #selector(UIResponder.delete(_:)) {
            // If we can perform copy, we have a selection
            DispatchQueue.main.async { [weak self] in
                self?.hasSelection = canPerform
            }
        }

        return canPerform
    }

    // MARK: - Touch Handling for Selection Detection

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Check selection state after touch begins
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkSelectionState()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // Check selection state after touch ends
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkSelectionState()
        }
    }

    /// Check if there's currently a selection by querying if copy is available
    private func checkSelectionState() {
        let canCopy = self.canPerformAction(#selector(UIResponder.copy(_:)), withSender: nil)
        if canCopy != hasSelection {
            hasSelection = canCopy
        }
    }
}
