//
//  PDFExporter.swift
//  Reef
//
//  Service for exporting annotated PDFs with flattened drawings

import UIKit
import PDFKit
import PencilKit

class PDFExporter {
    static let shared = PDFExporter()

    private init() {}

    /// Exports a PDF with annotations flattened (burned in)
    /// - Parameters:
    ///   - pdfURL: URL of the source PDF
    ///   - drawings: Dictionary of page index to PKDrawing
    /// - Returns: URL of the exported PDF, or nil if export failed
    func exportAnnotatedPDF(pdfURL: URL, drawings: [Int: PKDrawing]) -> URL? {
        guard let document = PDFDocument(url: pdfURL) else {
            return nil
        }

        // Create output URL
        let outputFileName = "annotated_\(UUID().uuidString).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)

        // Create a new PDF document with flattened annotations
        guard let flattenedDocument = createFlattenedPDF(from: document, drawings: drawings) else {
            return nil
        }

        // Write to file
        if flattenedDocument.write(to: outputURL) {
            // Show share sheet
            presentShareSheet(for: outputURL)
            return outputURL
        }

        return nil
    }

    private func createFlattenedPDF(from document: PDFDocument, drawings: [Int: PKDrawing]) -> PDFDocument? {
        let outputDocument = PDFDocument()

        for pageIndex in 0..<document.pageCount {
            guard let originalPage = document.page(at: pageIndex) else { continue }

            let pageRect = originalPage.bounds(for: .mediaBox)

            // Create a new page with the original content and drawing overlay
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

            let data = renderer.pdfData { context in
                context.beginPage()

                // Draw the original PDF page
                let cgContext = context.cgContext
                cgContext.saveGState()

                // PDFPage draws upside down, so we need to flip the coordinate system
                cgContext.translateBy(x: 0, y: pageRect.height)
                cgContext.scaleBy(x: 1, y: -1)

                originalPage.draw(with: .mediaBox, to: cgContext)

                cgContext.restoreGState()

                // Draw the PencilKit drawing on top
                if let drawing = drawings[pageIndex] {
                    let image = drawing.image(from: drawing.bounds, scale: 1.0)

                    // Calculate the position to draw the annotation
                    // The drawing bounds may not match the page bounds, so we need to position it correctly
                    let drawRect = CGRect(
                        x: drawing.bounds.origin.x,
                        y: pageRect.height - drawing.bounds.origin.y - drawing.bounds.height,
                        width: drawing.bounds.width,
                        height: drawing.bounds.height
                    )

                    image.draw(in: drawRect)
                }
            }

            // Create a PDFDocument from the rendered data and get the page
            if let tempDoc = PDFDocument(data: data),
               let newPage = tempDoc.page(at: 0) {
                outputDocument.insert(newPage, at: outputDocument.pageCount)
            }
        }

        return outputDocument.pageCount > 0 ? outputDocument : nil
    }

    private func presentShareSheet(for url: URL) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }

            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )

            // Configure for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            rootViewController.present(activityVC, animated: true)
        }
    }

    /// Exports annotations only (without the underlying PDF) as a separate file
    func exportAnnotationsOnly(drawings: [Int: PKDrawing], documentId: UUID) -> URL? {
        let encoder = JSONEncoder()

        var pageDrawings: [PageDrawingExport] = []
        for (pageIndex, drawing) in drawings.sorted(by: { $0.key < $1.key }) {
            pageDrawings.append(PageDrawingExport(
                pageIndex: pageIndex,
                drawingData: drawing.dataRepresentation()
            ))
        }

        let export = AnnotationsExport(
            documentId: documentId,
            exportDate: Date(),
            drawings: pageDrawings
        )

        guard let data = try? encoder.encode(export) else {
            return nil
        }

        let fileName = "annotations_\(documentId.uuidString).reef"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: outputURL)
            return outputURL
        } catch {
            print("Failed to export annotations: \(error)")
            return nil
        }
    }
}

// MARK: - Export Data Structures

struct PageDrawingExport: Codable {
    let pageIndex: Int
    let drawingData: Data
}

struct AnnotationsExport: Codable {
    let documentId: UUID
    let exportDate: Date
    let drawings: [PageDrawingExport]
}
