//
//  PDFThumbnailGenerator.swift
//  Reef
//

import UIKit
import PDFKit

struct PDFThumbnailGenerator {

    /// Sage Mist background color (#D7D9CE) for themed thumbnails
    private static let sageMistColor = UIColor(red: 215/255, green: 217/255, blue: 206/255, alpha: 1)

    /// Generates a thumbnail image from the first page of a PDF
    /// - Parameters:
    ///   - url: URL to the PDF file
    ///   - size: Target size for the thumbnail
    ///   - backgroundColor: Background color for the thumbnail (defaults to Sage Mist)
    /// - Returns: UIImage thumbnail or nil if generation fails
    static func generateThumbnail(
        from url: URL,
        size: CGSize = CGSize(width: 200, height: 280),
        backgroundColor: UIColor? = nil
    ) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let scale = min(size.width / pageRect.width, size.height / pageRect.height)
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            // Fill background with target color
            (backgroundColor ?? sageMistColor).setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))

            // Set multiply blend mode before drawing PDF
            // This transforms: white → background color, black → stays black
            context.cgContext.setBlendMode(.multiply)

            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image
    }

    /// Generates thumbnail data from a PDF URL
    /// - Parameter url: URL to the PDF file
    /// - Returns: JPEG data of the thumbnail or nil if generation fails
    static func generateThumbnailData(from url: URL) -> Data? {
        guard let image = generateThumbnail(from: url) else {
            return nil
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
