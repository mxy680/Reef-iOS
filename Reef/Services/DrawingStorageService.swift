//
//  DrawingStorageService.swift
//  Reef
//
//  Service for persisting PencilKit drawings to disk
//

import Foundation
import PencilKit

// MARK: - Assignment Structure Model

/// Tracks multi-page state per question in assignment mode
struct AssignmentStructure: Codable {
    /// Number of pages for each question (indexed by question index)
    var pageCounts: [Int]

    /// Creates a default structure where every question has 1 page
    static func defaultStructure(questionCount: Int) -> AssignmentStructure {
        AssignmentStructure(pageCounts: Array(repeating: 1, count: questionCount))
    }
}

// MARK: - Document Structure Model

/// Represents the structure of a multi-page document with modifications
struct DocumentStructure: Codable {
    /// Represents a single page in the document
    struct Page: Codable {
        enum PageType: String, Codable {
            case original  // Page from the original PDF/image
            case blank     // User-added blank page
        }

        let type: PageType
        let originalIndex: Int?  // For original pages, the index in the source file
    }

    var pages: [Page]
    let originalPageCount: Int  // Number of pages in the original source file

    /// Creates a default structure for a document with the given page count
    static func defaultStructure(pageCount: Int) -> DocumentStructure {
        let pages = (0..<pageCount).map { Page(type: .original, originalIndex: $0) }
        return DocumentStructure(pages: pages, originalPageCount: pageCount)
    }
}

class DrawingStorageService {
    static let shared = DrawingStorageService()

    private let fileManager = FileManager.default

    private var drawingsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drawings")
    }

    private var structuresDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DocumentStructures")
    }

    private init() {
        // Create directories if they don't exist
        if !fileManager.fileExists(atPath: drawingsDirectory.path) {
            try? fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: structuresDirectory.path) {
            try? fileManager.createDirectory(at: structuresDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Legacy Single-Page API (for backward compatibility)

    /// Saves a drawing to disk for the given document ID (legacy single-page)
    func saveDrawing(_ drawing: PKDrawing, for documentID: UUID) throws {
        try saveDrawing(drawing, for: documentID, pageIndex: 0)
    }

    /// Loads a drawing from disk for the given document ID (legacy single-page)
    /// Returns nil if no drawing exists or if loading fails
    func loadDrawing(for documentID: UUID) -> PKDrawing? {
        return loadDrawing(for: documentID, pageIndex: 0)
    }

    /// Deletes the drawing file for the given document ID (legacy - deletes all pages)
    func deleteDrawing(for documentID: UUID) {
        // Delete all page drawings
        let prefix = documentID.uuidString
        if let files = try? fileManager.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for file in files where file.hasPrefix(prefix) {
                try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(file))
            }
        }
        // Delete structure file
        let structureURL = getStructureURL(for: documentID)
        if fileManager.fileExists(atPath: structureURL.path) {
            try? fileManager.removeItem(at: structureURL)
        }
    }

    /// Checks if a drawing exists for the given document ID
    func drawingExists(for documentID: UUID) -> Bool {
        fileManager.fileExists(atPath: getDrawingURL(for: documentID, pageIndex: 0).path)
    }

    // MARK: - Multi-Page API

    /// Saves a drawing to disk for a specific page
    func saveDrawing(_ drawing: PKDrawing, for documentID: UUID, pageIndex: Int) throws {
        let url = getDrawingURL(for: documentID, pageIndex: pageIndex)
        let data = drawing.dataRepresentation()
        try data.write(to: url)
    }

    /// Loads a drawing from disk for a specific page
    func loadDrawing(for documentID: UUID, pageIndex: Int) -> PKDrawing? {
        let url = getDrawingURL(for: documentID, pageIndex: pageIndex)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        return drawing
    }

    /// Saves all drawings for a document
    func saveAllDrawings(_ drawings: [PKDrawing], for documentID: UUID) throws {
        for (index, drawing) in drawings.enumerated() {
            try saveDrawing(drawing, for: documentID, pageIndex: index)
        }
        // Clean up any drawings for pages that no longer exist
        cleanupExtraDrawings(for: documentID, keepingCount: drawings.count)
    }

    /// Loads all drawings for a document
    func loadAllDrawings(for documentID: UUID, pageCount: Int) -> [PKDrawing] {
        return (0..<pageCount).map { index in
            loadDrawing(for: documentID, pageIndex: index) ?? PKDrawing()
        }
    }

    // MARK: - Assignment Mode (Per-Question) API

    /// Saves a drawing for a specific question in assignment mode
    func saveQuestionDrawing(_ drawing: PKDrawing, for documentID: UUID, questionIndex: Int) throws {
        let url = getQuestionDrawingURL(for: documentID, questionIndex: questionIndex)
        let data = drawing.dataRepresentation()
        try data.write(to: url)
    }

    /// Loads a drawing for a specific question in assignment mode
    func loadQuestionDrawing(for documentID: UUID, questionIndex: Int) -> PKDrawing? {
        let url = getQuestionDrawingURL(for: documentID, questionIndex: questionIndex)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        return drawing
    }

    /// Saves all question drawings for assignment mode
    func saveAllQuestionDrawings(_ drawings: [PKDrawing], for documentID: UUID) throws {
        for (index, drawing) in drawings.enumerated() {
            try saveQuestionDrawing(drawing, for: documentID, questionIndex: index)
        }
    }

    /// Loads all question drawings for assignment mode
    func loadAllQuestionDrawings(for documentID: UUID, questionCount: Int) -> [PKDrawing] {
        return (0..<questionCount).map { index in
            loadQuestionDrawing(for: documentID, questionIndex: index) ?? PKDrawing()
        }
    }

    // MARK: - Assignment Mode (Per-Question, Per-Page) API

    /// Saves a drawing for a specific page within a specific question in assignment mode
    func saveQuestionPageDrawing(_ drawing: PKDrawing, for documentID: UUID, questionIndex: Int, pageIndex: Int) throws {
        let url = getQuestionPageDrawingURL(for: documentID, questionIndex: questionIndex, pageIndex: pageIndex)
        let data = drawing.dataRepresentation()
        try data.write(to: url)
    }

    /// Loads a drawing for a specific page within a specific question in assignment mode.
    /// Falls back to legacy single-page question drawing for page 0 if new format doesn't exist.
    func loadQuestionPageDrawing(for documentID: UUID, questionIndex: Int, pageIndex: Int) -> PKDrawing? {
        let url = getQuestionPageDrawingURL(for: documentID, questionIndex: questionIndex, pageIndex: pageIndex)
        if fileManager.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let drawing = try? PKDrawing(data: data) {
            return drawing
        }
        // Legacy fallback: for page 0, try the old single-page question drawing
        if pageIndex == 0 {
            return loadQuestionDrawing(for: documentID, questionIndex: questionIndex)
        }
        return nil
    }

    /// Saves all page drawings for a specific question
    func saveAllQuestionPageDrawings(_ drawings: [PKDrawing], for documentID: UUID, questionIndex: Int) throws {
        for (pageIndex, drawing) in drawings.enumerated() {
            try saveQuestionPageDrawing(drawing, for: documentID, questionIndex: questionIndex, pageIndex: pageIndex)
        }
    }

    /// Loads all page drawings for a specific question
    func loadAllQuestionPageDrawings(for documentID: UUID, questionIndex: Int, pageCount: Int) -> [PKDrawing] {
        return (0..<pageCount).map { pageIndex in
            loadQuestionPageDrawing(for: documentID, questionIndex: questionIndex, pageIndex: pageIndex) ?? PKDrawing()
        }
    }

    /// Cleans up orphaned question-page drawings after page deletion (indices shifted)
    func cleanupQuestionPageDrawings(for documentID: UUID, questionIndex: Int, keepingCount: Int) {
        let prefix = "\(documentID.uuidString)_question\(questionIndex)_page"
        if let files = try? fileManager.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for file in files where file.hasPrefix(prefix) && file.hasSuffix(".drawing") {
                // Extract page index from filename: {UUID}_question{q}_page{p}.drawing
                let withoutPrefix = String(file.dropFirst(prefix.count))
                if let dotIndex = withoutPrefix.firstIndex(of: "."),
                   let pageIndex = Int(withoutPrefix[withoutPrefix.startIndex..<dotIndex]),
                   pageIndex >= keepingCount {
                    try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(file))
                }
            }
        }
    }

    // MARK: - Assignment Structure API

    /// Saves the assignment structure (per-question page counts)
    func saveAssignmentStructure(_ structure: AssignmentStructure, for documentID: UUID) throws {
        let url = getAssignmentStructureURL(for: documentID)
        let data = try JSONEncoder().encode(structure)
        try data.write(to: url)
    }

    /// Loads the assignment structure
    func loadAssignmentStructure(for documentID: UUID) -> AssignmentStructure? {
        let url = getAssignmentStructureURL(for: documentID)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let structure = try? JSONDecoder().decode(AssignmentStructure.self, from: data) else {
            return nil
        }
        return structure
    }

    // MARK: - Document Structure API

    /// Saves the document structure
    func saveDocumentStructure(_ structure: DocumentStructure, for documentID: UUID) throws {
        let url = getStructureURL(for: documentID)
        let data = try JSONEncoder().encode(structure)
        try data.write(to: url)
    }

    /// Loads the document structure
    func loadDocumentStructure(for documentID: UUID) -> DocumentStructure? {
        let url = getStructureURL(for: documentID)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let structure = try? JSONDecoder().decode(DocumentStructure.self, from: data) else {
            return nil
        }
        return structure
    }

    // MARK: - Private

    private func getDrawingURL(for documentID: UUID, pageIndex: Int) -> URL {
        drawingsDirectory.appendingPathComponent("\(documentID.uuidString)_page\(pageIndex).drawing")
    }

    private func getQuestionDrawingURL(for documentID: UUID, questionIndex: Int) -> URL {
        drawingsDirectory.appendingPathComponent("\(documentID.uuidString)_question\(questionIndex).drawing")
    }

    private func getQuestionPageDrawingURL(for documentID: UUID, questionIndex: Int, pageIndex: Int) -> URL {
        drawingsDirectory.appendingPathComponent("\(documentID.uuidString)_question\(questionIndex)_page\(pageIndex).drawing")
    }

    private func getStructureURL(for documentID: UUID) -> URL {
        structuresDirectory.appendingPathComponent("\(documentID.uuidString).structure")
    }

    private func getAssignmentStructureURL(for documentID: UUID) -> URL {
        structuresDirectory.appendingPathComponent("\(documentID.uuidString)_assignment.structure")
    }

    private func cleanupExtraDrawings(for documentID: UUID, keepingCount: Int) {
        let prefix = documentID.uuidString
        if let files = try? fileManager.contentsOfDirectory(atPath: drawingsDirectory.path) {
            for file in files where file.hasPrefix(prefix) {
                // Extract page index from filename
                if let range = file.range(of: "_page"),
                   let endRange = file.range(of: ".drawing"),
                   let pageIndex = Int(file[range.upperBound..<endRange.lowerBound]),
                   pageIndex >= keepingCount {
                    try? fileManager.removeItem(at: drawingsDirectory.appendingPathComponent(file))
                }
            }
        }
    }
}
