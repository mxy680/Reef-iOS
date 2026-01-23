//
//  PDFThumbnailGenerator.swift
//  Reef
//

import UIKit
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct PDFThumbnailGenerator {

    /// Sage Mist background color (#D7D9CE) for light mode thumbnails
    private static let sageMistColor = UIColor(red: 215/255, green: 217/255, blue: 206/255, alpha: 1)

    /// Deep Ocean background color (#0A1628) for dark mode thumbnails
    private static let deepOceanColor = UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)

    /// Generates a thumbnail image from the first page of a PDF at a fixed canvas size
    /// - Parameters:
    ///   - url: URL to the PDF file
    ///   - size: Fixed canvas size for the thumbnail (content is scaled to fit and centered)
    ///   - isDarkMode: Whether to generate a dark mode thumbnail
    /// - Returns: UIImage thumbnail or nil if generation fails
    static func generateThumbnail(
        from url: URL,
        size: CGSize = CGSize(width: 180, height: 200),  // 9:10 ratio matching card aspect
        isDarkMode: Bool = false
    ) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return nil
        }

        if isDarkMode {
            return generateDarkModeThumbnail(page: page, size: size)
        } else {
            return generateLightModeThumbnail(page: page, size: size)
        }
    }

    /// Generates a light mode thumbnail with Sage Mist background
    private static func generateLightModeThumbnail(page: PDFPage, size: CGSize) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)

        // Zoom in to crop document edges (1/0.9 ≈ 1.11x zoom)
        let zoomFactor: CGFloat = 1.0 / 0.9
        let scale = (size.width / pageRect.width) * zoomFactor
        let scaledWidth = pageRect.width * scale
        let scaledHeight = pageRect.height * scale

        // Center horizontally (crops equal from left and right)
        let xOffset = (size.width - scaledWidth) / 2

        // Crop a bit from top to hide top margin
        let topCrop = pageRect.height * 0.02 * scale

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Fill with Sage Mist background
            sageMistColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Multiply blend: white → sage mist, black → black
            context.cgContext.setBlendMode(.multiply)

            context.cgContext.translateBy(x: xOffset, y: scaledHeight - topCrop)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    /// Generates a dark mode thumbnail with Deep Ocean background and light content
    private static func generateDarkModeThumbnail(page: PDFPage, size: CGSize) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)

        // Zoom in to crop document edges (1/0.9 ≈ 1.11x zoom)
        let zoomFactor: CGFloat = 1.0 / 0.9
        let scale = (size.width / pageRect.width) * zoomFactor
        let scaledWidth = pageRect.width * scale
        let scaledHeight = pageRect.height * scale

        // Center horizontally (crops equal from left and right)
        let xOffset = (size.width - scaledWidth) / 2

        // Crop a bit from top to hide top margin
        let topCrop = pageRect.height * 0.02 * scale

        // First render the PDF normally (white background, black content)
        let renderer = UIGraphicsImageRenderer(size: size)
        let normalImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            context.cgContext.translateBy(x: xOffset, y: scaledHeight - topCrop)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        // Apply false color filter to map grayscale to specific colors
        // This provides precise color mapping: black → white (text), white → Deep Ocean (background)
        guard let ciImage = CIImage(image: normalImage) else { return normalImage }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = ciImage
        // color0: Black pixels (text) → White for readability
        falseColor.color0 = CIColor(red: 1, green: 1, blue: 1)
        // color1: White pixels (background) → Deep Ocean (#0A1628)
        falseColor.color1 = CIColor(red: 10/255, green: 22/255, blue: 40/255)

        guard let tintedImage = falseColor.outputImage else { return normalImage }

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(tintedImage, from: tintedImage.extent) else {
            return normalImage
        }

        return UIImage(cgImage: cgImage)
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
