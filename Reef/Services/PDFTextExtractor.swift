//
//  PDFTextExtractor.swift
//  Reef
//

import PDFKit

class PDFTextExtractor {
    static let shared = PDFTextExtractor()

    private init() {}

    func extractText(from url: URL) async -> String? {
        guard let document = PDFDocument(url: url) else { return nil }

        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        return fullText.isEmpty ? nil : fullText
    }
}
