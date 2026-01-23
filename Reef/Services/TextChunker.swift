//
//  TextChunker.swift
//  Reef
//
//  Splits documents into semantic chunks for vector indexing.
//  Prioritizes section headers, page breaks, and paragraph boundaries.
//

import Foundation

/// Type of document being chunked
enum DocumentType: String, Codable {
    case note
    case assignment
}

/// A chunk of text from a document with metadata
struct TextChunk: Identifiable {
    let id: String
    let text: String
    let documentId: UUID
    let documentType: DocumentType
    let position: Int
    let pageNumber: Int?
    let heading: String?

    /// Create a chunk with auto-generated ID
    init(
        text: String,
        documentId: UUID,
        documentType: DocumentType,
        position: Int,
        pageNumber: Int? = nil,
        heading: String? = nil
    ) {
        self.id = "\(documentId.uuidString)-\(position)"
        self.text = text
        self.documentId = documentId
        self.documentType = documentType
        self.position = position
        self.pageNumber = pageNumber
        self.heading = heading
    }
}

/// Service for splitting documents into semantic chunks
struct TextChunker {
    /// Target chunk size in characters
    static let targetChunkSize = 1000

    /// Minimum chunk size (smaller chunks get merged)
    static let minChunkSize = 200

    /// Maximum chunk size before forcing a split
    static let maxChunkSize = 1500

    // MARK: - Regex Patterns

    /// Pattern for section headers (chapters, numbered sections, all-caps lines)
    private static let headerPatterns: [NSRegularExpression] = {
        let patterns = [
            // Chapter headers: "Chapter 1", "CHAPTER ONE"
            "^\\s*(?:chapter|CHAPTER)\\s+(?:\\d+|[IVXLCDM]+|[a-zA-Z]+)\\s*[:.]?\\s*.*$",
            // Numbered sections: "1.", "1.1", "1.1.1", "Section 1"
            "^\\s*(?:(?:section|Section|SECTION)\\s+)?\\d+(?:\\.\\d+)*\\.?\\s+[A-Z].*$",
            // Roman numeral sections: "I.", "II.", "III."
            "^\\s*[IVXLCDM]+\\.\\s+.*$",
            // All caps headers (at least 3 words, min 10 chars)
            "^\\s*[A-Z][A-Z\\s]{10,}$",
            // Headers with colons: "Introduction:", "Summary:"
            "^\\s*[A-Z][a-zA-Z\\s]+:\\s*$"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .anchorsMatchLines) }
    }()

    /// Pattern for page breaks
    private static let pageBreakPattern = try! NSRegularExpression(
        pattern: "\\f|(?:^|\\n)\\s*(?:Page|PAGE)\\s+\\d+\\s*(?:\\n|$)|(?:^|\\n)-{3,}\\s*(?:\\n|$)",
        options: []
    )

    // MARK: - Public API

    /// Split text into semantic chunks
    /// - Parameters:
    ///   - text: The full document text
    ///   - documentId: UUID of the source document
    ///   - documentType: Type of document (.note or .assignment)
    /// - Returns: Array of text chunks with metadata
    static func chunk(
        text: String,
        documentId: UUID,
        documentType: DocumentType
    ) -> [TextChunk] {
        guard !text.isEmpty else { return [] }

        // First, split by major boundaries (page breaks, headers)
        let segments = splitByBoundaries(text)

        // Then, process each segment into appropriately sized chunks
        var chunks: [TextChunk] = []
        var currentHeading: String? = nil
        var currentPage: Int = 1
        var position = 0

        for segment in segments {
            // Check if this segment is a header
            if let header = extractHeader(from: segment) {
                currentHeading = header
                continue
            }

            // Check if this is a page break marker
            if isPageBreak(segment) {
                currentPage += 1
                continue
            }

            // Split segment into paragraph-sized chunks
            let paragraphChunks = splitIntoParagraphChunks(segment)

            for paragraphChunk in paragraphChunks {
                let trimmed = paragraphChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= Self.minChunkSize else { continue }

                // Prepend heading to chunk for context
                let chunkText = if let heading = currentHeading {
                    "[\(heading)]\n\n\(trimmed)"
                } else {
                    trimmed
                }

                chunks.append(TextChunk(
                    text: chunkText,
                    documentId: documentId,
                    documentType: documentType,
                    position: position,
                    pageNumber: currentPage,
                    heading: currentHeading
                ))
                position += 1
            }
        }

        // Merge small adjacent chunks
        return mergeSmallChunks(chunks, documentId: documentId, documentType: documentType)
    }

    // MARK: - Private Helpers

    /// Split text by major boundaries (page breaks, section headers)
    private static func splitByBoundaries(_ text: String) -> [String] {
        var segments: [String] = []
        var currentSegment = ""
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            // Check if line is a header
            if isHeader(line) {
                // Save current segment
                if !currentSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(currentSegment)
                }
                // Add header as its own segment
                segments.append(line)
                currentSegment = ""
                continue
            }

            // Check if line contains a page break
            if containsPageBreak(line) {
                // Save current segment
                if !currentSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(currentSegment)
                }
                // Mark page break
                segments.append("[PAGE_BREAK]")
                currentSegment = ""
                continue
            }

            currentSegment += line + "\n"
        }

        // Don't forget the last segment
        if !currentSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    /// Check if a line is a section header
    private static func isHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 && trimmed.count <= 200 else { return false }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        for pattern in headerPatterns {
            if pattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    /// Extract the header text from a line
    private static func extractHeader(from segment: String) -> String? {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHeader(trimmed) else { return nil }
        return trimmed
    }

    /// Check if text contains a page break marker
    private static func containsPageBreak(_ text: String) -> Bool {
        // Check for form feed character
        if text.contains("\u{000C}") { return true }

        // Check for page number patterns
        let range = NSRange(text.startIndex..., in: text)
        return pageBreakPattern.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Check if segment is a page break marker
    private static func isPageBreak(_ segment: String) -> Bool {
        return segment == "[PAGE_BREAK]"
    }

    /// Split a segment into paragraph-sized chunks
    private static func splitIntoParagraphChunks(_ text: String) -> [String] {
        // First try splitting by double newlines (paragraphs)
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk = ""

        for paragraph in paragraphs {
            // If adding this paragraph would exceed max size, save current and start new
            if currentChunk.count + paragraph.count + 2 > Self.maxChunkSize {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }

                // If single paragraph is too large, split by sentences
                if paragraph.count > Self.maxChunkSize {
                    chunks.append(contentsOf: splitBySentences(paragraph))
                    currentChunk = ""
                } else {
                    currentChunk = paragraph
                }
            } else if currentChunk.count + paragraph.count + 2 > Self.targetChunkSize {
                // If we've reached target size, save and start new
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = paragraph
            } else {
                // Add to current chunk
                if currentChunk.isEmpty {
                    currentChunk = paragraph
                } else {
                    currentChunk += "\n\n" + paragraph
                }
            }
        }

        // Don't forget the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    /// Split text by sentences (fallback for very long paragraphs)
    private static func splitBySentences(_ text: String) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        // Simple sentence boundary detection
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var remaining = text

        while !remaining.isEmpty {
            // Find next sentence ending
            if let range = remaining.rangeOfCharacter(from: sentenceEndings) {
                let sentenceEnd = remaining.index(after: range.lowerBound)
                let sentence = String(remaining[..<sentenceEnd]).trimmingCharacters(in: .whitespaces)

                if currentChunk.count + sentence.count + 1 > Self.targetChunkSize && !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    currentChunk = sentence
                } else {
                    currentChunk += (currentChunk.isEmpty ? "" : " ") + sentence
                }

                remaining = String(remaining[sentenceEnd...]).trimmingCharacters(in: .whitespaces)
            } else {
                // No more sentence endings, add remainder
                currentChunk += (currentChunk.isEmpty ? "" : " ") + remaining
                break
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    /// Merge small adjacent chunks
    private static func mergeSmallChunks(
        _ chunks: [TextChunk],
        documentId: UUID,
        documentType: DocumentType
    ) -> [TextChunk] {
        guard chunks.count > 1 else { return chunks }

        var merged: [TextChunk] = []
        var pending: TextChunk? = nil

        for chunk in chunks {
            if let p = pending {
                // If both are small, merge them
                if p.text.count < Self.minChunkSize && chunk.text.count < Self.minChunkSize {
                    pending = TextChunk(
                        text: p.text + "\n\n" + chunk.text,
                        documentId: documentId,
                        documentType: documentType,
                        position: p.position,
                        pageNumber: p.pageNumber,
                        heading: p.heading ?? chunk.heading
                    )
                } else if p.text.count < Self.minChunkSize {
                    // Merge small pending into current
                    merged.append(TextChunk(
                        text: p.text + "\n\n" + chunk.text,
                        documentId: documentId,
                        documentType: documentType,
                        position: p.position,
                        pageNumber: p.pageNumber,
                        heading: p.heading ?? chunk.heading
                    ))
                    pending = nil
                } else {
                    // Pending is big enough, save it
                    merged.append(p)
                    pending = chunk
                }
            } else {
                pending = chunk
            }
        }

        // Don't forget the last pending chunk
        if let p = pending {
            merged.append(p)
        }

        // Renumber positions
        return merged.enumerated().map { index, chunk in
            TextChunk(
                text: chunk.text,
                documentId: chunk.documentId,
                documentType: chunk.documentType,
                position: index,
                pageNumber: chunk.pageNumber,
                heading: chunk.heading
            )
        }
    }
}
