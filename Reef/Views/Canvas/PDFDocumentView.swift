//
//  PDFDocumentView.swift
//  Reef
//
//  UIViewRepresentable wrapper for PDFKit's PDFView

import SwiftUI
import UIKit
import PDFKit

struct PDFDocumentView: UIViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    let onPageChange: ((Int) -> Void)?

    init(url: URL, currentPageIndex: Binding<Int>, onPageChange: ((Int) -> Void)? = nil) {
        self.url = url
        self._currentPageIndex = currentPageIndex
        self.onPageChange = onPageChange
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        pdfView.pageShadowsEnabled = false
        pdfView.pageBreakMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Enable user interaction for scrolling
        pdfView.isUserInteractionEnabled = true

        // Set up notification for page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update document if URL changed
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChange: onPageChange, currentPageIndex: $currentPageIndex)
    }

    class Coordinator: NSObject {
        weak var pdfView: PDFView?
        var onPageChange: ((Int) -> Void)?
        @Binding var currentPageIndex: Int

        init(onPageChange: ((Int) -> Void)?, currentPageIndex: Binding<Int>) {
            self.onPageChange = onPageChange
            self._currentPageIndex = currentPageIndex
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }

            let pageIndex = document.index(for: currentPage)

            DispatchQueue.main.async { [weak self] in
                self?.currentPageIndex = pageIndex
                self?.onPageChange?(pageIndex)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - PDFView Extensions

extension PDFView {
    /// Returns the page count of the current document
    var pageCount: Int {
        document?.pageCount ?? 0
    }

    /// Scrolls to a specific page index
    func scrollToPage(at index: Int) {
        guard let document = document,
              let page = document.page(at: index) else {
            return
        }
        go(to: page)
    }

    /// Returns the visible bounds in PDF coordinates for a specific page
    func visibleBounds(for page: PDFPage) -> CGRect {
        convert(bounds, to: page)
    }
}
