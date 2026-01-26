//
//  ReefCanvasView.swift
//  Reef
//
//  Custom PKCanvasView subclass for clipboard operations
//

import PencilKit
import UIKit

class ReefCanvasView: PKCanvasView {

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
