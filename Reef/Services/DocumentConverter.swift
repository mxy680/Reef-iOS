//
//  DocumentConverter.swift
//  Reef
//
//  Converts images to PDF format for unified annotation handling

import UIKit
import PDFKit

class DocumentConverter {
    static let shared = DocumentConverter()

    private init() {}

    /// Converts an image file to PDF
    /// - Parameters:
    ///   - imageURL: URL of the source image
    ///   - destinationURL: URL where the PDF should be saved
    /// - Returns: URL of the created PDF, or nil if conversion failed
    func convertImageToPDF(from imageURL: URL, to destinationURL: URL) -> URL? {
        // Start accessing security-scoped resource if needed
        let accessing = imageURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                imageURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }

        return createPDF(from: image, destinationURL: destinationURL)
    }

    /// Creates a PDF from a UIImage
    /// - Parameters:
    ///   - image: The source image
    ///   - destinationURL: URL where the PDF should be saved
    /// - Returns: URL of the created PDF, or nil if creation failed
    func createPDF(from image: UIImage, destinationURL: URL) -> URL? {
        // Use the image size as the PDF page size (in points)
        let pageRect = CGRect(origin: .zero, size: image.size)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: destinationURL) { context in
                context.beginPage()
                image.draw(in: pageRect)
            }
            return destinationURL
        } catch {
            print("Failed to create PDF from image: \(error)")
            return nil
        }
    }

    /// Creates a blank PDF with the specified size
    /// - Parameters:
    ///   - size: The size of each page in points
    ///   - pageCount: Number of pages to create (default 1)
    ///   - destinationURL: URL where the PDF should be saved
    /// - Returns: URL of the created PDF, or nil if creation failed
    func createBlankPDF(size: CGSize, pageCount: Int = 1, destinationURL: URL) -> URL? {
        let pageRect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: destinationURL) { context in
                for _ in 0..<pageCount {
                    context.beginPage()
                    // Fill with white background
                    UIColor.white.setFill()
                    UIRectFill(pageRect)
                }
            }
            return destinationURL
        } catch {
            print("Failed to create blank PDF: \(error)")
            return nil
        }
    }

    /// Standard blank canvas size (iPad-friendly, letter-ish proportions)
    static let defaultCanvasSize = CGSize(width: 612, height: 792) // US Letter size in points

    /// Checks if a file is an image that should be converted to PDF
    func shouldConvertToPDF(fileExtension: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp"]
        return imageExtensions.contains(fileExtension.lowercased())
    }

    /// Adds a new blank page to an existing PDF
    /// - Parameters:
    ///   - pdfURL: URL of the existing PDF
    ///   - pageSize: Size of the new page (defaults to the size of the last page)
    /// - Returns: true if successful, false otherwise
    func addBlankPage(to pdfURL: URL, pageSize: CGSize? = nil) -> Bool {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            return false
        }

        // Determine page size
        let size: CGSize
        if let pageSize = pageSize {
            size = pageSize
        } else if let lastPage = pdfDocument.page(at: pdfDocument.pageCount - 1) {
            size = lastPage.bounds(for: .mediaBox).size
        } else {
            size = DocumentConverter.defaultCanvasSize
        }

        // Create a blank page
        let pageRect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        guard let _ = try? renderer.writePDF(to: tempURL, withActions: { context in
                  context.beginPage()
                  UIColor.white.setFill()
                  UIRectFill(pageRect)
              }),
              let tempDoc = PDFDocument(url: tempURL),
              let newPage = tempDoc.page(at: 0) else {
            return false
        }

        // Append the new page
        pdfDocument.insert(newPage, at: pdfDocument.pageCount)

        // Save the modified document
        let success = pdfDocument.write(to: pdfURL)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        return success
    }
}
