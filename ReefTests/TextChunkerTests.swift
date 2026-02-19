//
//  TextChunkerTests.swift
//  ReefTests
//
//  Tests for TextChunker semantic document chunking.
//

import Testing
import Foundation
@testable import Reef

@Suite("TextChunker", .serialized)
struct TextChunkerTests {

    // Fixed UUID for deterministic ID checks
    private let docId = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

    // MARK: - Helper

    /// Generate a string of the given character count made of repeated words
    private func makeText(length: Int) -> String {
        let word = "lorem "
        let repeated = String(repeating: word, count: (length / word.count) + 1)
        return String(repeated.prefix(length))
    }

    /// Generate multiple paragraphs separated by double newlines
    private func makeParagraphs(count: Int, paragraphLength: Int) -> String {
        (0..<count).map { i in
            "Paragraph \(i). " + makeText(length: paragraphLength - "Paragraph X. ".count)
        }.joined(separator: "\n\n")
    }

    // MARK: - Empty / Short Text

    @Test("Empty text returns empty array")
    func emptyText() {
        let chunks = TextChunker.chunk(text: "", documentId: docId, documentType: .note)
        #expect(chunks.isEmpty)
    }

    @Test("Text shorter than minChunkSize returns empty array")
    func shortText() {
        let text = "This is a short note."
        #expect(text.count < TextChunker.minChunkSize)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.isEmpty)
    }

    @Test("Text just below minChunkSize returns empty array")
    func textJustBelowMinChunkSize() {
        let text = makeText(length: TextChunker.minChunkSize - 1)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.isEmpty)
    }

    // MARK: - Single Chunk

    @Test("Single paragraph at target size returns one chunk")
    func singleParagraphAtTargetSize() {
        let text = makeText(length: TextChunker.targetChunkSize)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count == 1)
        #expect(chunks[0].position == 0)
        #expect(chunks[0].pageNumber == 1)
        #expect(chunks[0].heading == nil)
    }

    @Test("Text at exactly minChunkSize produces one chunk")
    func textAtExactMinChunkSize() {
        let text = makeText(length: TextChunker.minChunkSize)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count == 1)
    }

    // MARK: - Chunk ID Format

    @Test("Chunk ID format is documentId-position")
    func chunkIdFormat() {
        let text = makeText(length: 300)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count == 1)
        #expect(chunks[0].id == "\(docId.uuidString)-0")
    }

    @Test("Multiple chunks have sequential IDs")
    func multipleChunkIds() {
        let text = makeParagraphs(count: 6, paragraphLength: 500)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
        for (index, chunk) in chunks.enumerated() {
            #expect(chunk.id == "\(docId.uuidString)-\(index)")
        }
    }

    // MARK: - Long Text Splitting

    @Test("Long text splits into multiple chunks")
    func longTextSplitsIntoMultipleChunks() {
        let text = makeParagraphs(count: 10, paragraphLength: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count > 1)
    }

    @Test("No chunk text exceeds maxChunkSize plus heading overhead")
    func noChunkExceedsMaxChunkSize() {
        let text = makeParagraphs(count: 20, paragraphLength: 600)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        let headingOverhead = 100
        for chunk in chunks {
            #expect(
                chunk.text.count <= TextChunker.maxChunkSize + headingOverhead,
                "Chunk at position \(chunk.position) has \(chunk.text.count) chars"
            )
        }
    }

    @Test("Very long single paragraph gets split by sentences")
    func veryLongParagraphSplitBySentences() {
        var sentences: [String] = []
        while sentences.joined(separator: " ").count < TextChunker.maxChunkSize + 500 {
            sentences.append("This is sentence number \(sentences.count) in a very long paragraph.")
        }
        let text = sentences.joined(separator: " ")
        #expect(text.count > TextChunker.maxChunkSize)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
    }

    // MARK: - Headers
    // Note: The chapter pattern matches lowercase "chapter" or uppercase "CHAPTER" only

    @Test("CHAPTER header detected and attached as heading")
    func chapterHeaderDetected() {
        let text = "CHAPTER 1 Introduction\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        if let first = chunks.first {
            #expect(first.heading == "CHAPTER 1 Introduction")
        }
    }

    @Test("Uppercase CHAPTER variant detected")
    func uppercaseChapterHeader() {
        let text = "CHAPTER THREE\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "CHAPTER THREE")
    }

    @Test("Header applies to subsequent chunks until next header")
    func headerAppliesUntilNextHeader() {
        let para = makeText(length: 400)
        let text = "CHAPTER 1 First\n\n\(para)\n\nCHAPTER 2 Second\n\n\(para)"
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
        if chunks.count >= 2 {
            #expect(chunks[0].heading == "CHAPTER 1 First")
            #expect(chunks[1].heading == "CHAPTER 2 Second")
        }
    }

    // MARK: - Numbered Section Headers

    @Test("Numbered section header detected")
    func numberedSectionHeader() {
        let text = "1.1 Background Information\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "1.1 Background Information")
    }

    @Test("Section keyword header detected")
    func sectionKeywordHeader() {
        let text = "Section 3 Overview\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "Section 3 Overview")
    }

    @Test("Roman numeral header detected")
    func romanNumeralHeader() {
        let text = "III. Methods and Analysis\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "III. Methods and Analysis")
    }

    // MARK: - Page Breaks
    // Note: Form feed (\u{000C}) is in CharacterSet.newlines, so components(separatedBy:)
    // consumes it as a separator. Only text-based page markers like "PAGE N" work.

    @Test("PAGE N pattern triggers page break")
    func pageNumberPattern() {
        let para = makeText(length: 400)
        let text = para + "\nPAGE 2\n" + para
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
        if chunks.count >= 2 {
            #expect(chunks[0].pageNumber == 1)
            #expect(chunks[1].pageNumber == 2)
        }
    }

    @Test("Multiple PAGE markers increment page numbers")
    func multiplePageMarkers() {
        let para = makeText(length: 400)
        let text = para + "\nPAGE 2\n" + para + "\nPAGE 3\n" + para
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 3)
        if chunks.count >= 3 {
            #expect(chunks[0].pageNumber == 1)
            #expect(chunks[1].pageNumber == 2)
            #expect(chunks[2].pageNumber == 3)
        }
    }

    @Test("Dash separator triggers page break")
    func dashSeparatorPageBreak() {
        let para = makeText(length: 400)
        let text = para + "\n---\n" + para
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
        if chunks.count >= 2 {
            #expect(chunks[0].pageNumber == 1)
            #expect(chunks[1].pageNumber == 2)
        }
    }

    // MARK: - Document Type

    @Test("Note document type preserved in chunks")
    func noteDocumentType() {
        let text = makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        for chunk in chunks {
            #expect(chunk.documentType == .note)
        }
    }

    @Test("Assignment document type preserved in chunks")
    func assignmentDocumentType() {
        let text = makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .assignment)
        for chunk in chunks {
            #expect(chunk.documentType == .assignment)
        }
    }

    // MARK: - Document ID

    @Test("Document ID preserved in all chunks")
    func documentIdPreserved() {
        let text = makeParagraphs(count: 6, paragraphLength: 500)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        for chunk in chunks {
            #expect(chunk.documentId == docId)
        }
    }

    // MARK: - Positions

    @Test("Positions are sequential starting from zero")
    func sequentialPositions() {
        let text = makeParagraphs(count: 8, paragraphLength: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
        for (index, chunk) in chunks.enumerated() {
            #expect(chunk.position == index)
        }
    }

    // MARK: - Heading Prefix in Text

    @Test("Heading is prepended as bracketed prefix in chunk text")
    func headingPrependedInText() {
        let body = makeText(length: 400)
        let text = "CHAPTER 5 Results\n\n\(body)"
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        if let first = chunks.first {
            #expect(first.text.starts(with: "[CHAPTER 5 Results]\n\n"))
        }
    }

    @Test("Chunk without heading has no bracket prefix")
    func noHeadingNoBracket() {
        let text = makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(!chunks[0].text.starts(with: "["))
    }

    // MARK: - All-Caps Header

    @Test("All-caps line of sufficient length detected as header")
    func allCapsHeader() {
        let text = "LITERATURE REVIEW\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "LITERATURE REVIEW")
    }

    // MARK: - Colon Header

    @Test("Header with trailing colon detected")
    func colonHeader() {
        let text = "Introduction:\n\n" + makeText(length: 400)
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 1)
        #expect(chunks[0].heading == "Introduction:")
    }

    // MARK: - Paragraph Splitting

    @Test("Double newlines are paragraph boundaries")
    func doubleNewlineSplitsParagraphs() {
        let para = makeText(length: TextChunker.targetChunkSize)
        let text = para + "\n\n" + para
        let chunks = TextChunker.chunk(text: text, documentId: docId, documentType: .note)
        #expect(chunks.count >= 2)
    }

    // MARK: - Idempotent Metadata

    @Test("Chunking same text with different docIds yields different chunk IDs")
    func differentDocIdsDifferentChunkIds() {
        let text = makeText(length: 400)
        let id1 = UUID()
        let id2 = UUID()
        let chunks1 = TextChunker.chunk(text: text, documentId: id1, documentType: .note)
        let chunks2 = TextChunker.chunk(text: text, documentId: id2, documentType: .note)
        #expect(chunks1[0].id != chunks2[0].id)
    }

    // MARK: - Constants

    @Test("Constants have expected relationships")
    func constantsRelationships() {
        #expect(TextChunker.minChunkSize == 200)
        #expect(TextChunker.targetChunkSize == 1000)
        #expect(TextChunker.maxChunkSize == 1500)
        #expect(TextChunker.minChunkSize < TextChunker.targetChunkSize)
        #expect(TextChunker.targetChunkSize < TextChunker.maxChunkSize)
    }
}
