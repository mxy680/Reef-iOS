//
//  ReefCanvasView.swift
//  Reef
//
//  Custom PKCanvasView subclass for clipboard operations
//

import PencilKit
import UIKit

class ReefCanvasView: PKCanvasView {

    // MARK: - Selection State

    var onSelectionChanged: ((Bool) -> Void)?

    var hasSelection: Bool {
        canPerformAction(#selector(copy(_:)), withSender: nil)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let result = super.canPerformAction(action, withSender: sender)

        // Notify when selection-related actions change
        if action == #selector(copy(_:)) || action == #selector(cut(_:)) || action == #selector(delete(_:)) {
            DispatchQueue.main.async { [weak self] in
                self?.onSelectionChanged?(self?.hasSelection ?? false)
            }
        }

        return result
    }

    // MARK: - Clipboard Operations

    @objc override func paste(_ sender: Any?) {
        super.paste(sender)
    }

    func performPaste() {
        becomeFirstResponder()
        paste(nil)
    }

    func performCopy() {
        becomeFirstResponder()
        copy(nil)
    }

    func performCut() {
        becomeFirstResponder()
        cut(nil)
    }

    func performDelete() {
        becomeFirstResponder()
        delete(nil)
    }
}
