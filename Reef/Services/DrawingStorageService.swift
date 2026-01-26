//
//  DrawingStorageService.swift
//  Reef
//
//  Service for persisting PencilKit drawings to disk
//

import Foundation
import PencilKit

class DrawingStorageService {
    static let shared = DrawingStorageService()

    private let fileManager = FileManager.default

    private var drawingsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drawings")
    }

    private init() {
        // Create Drawings directory if it doesn't exist
        if !fileManager.fileExists(atPath: drawingsDirectory.path) {
            try? fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Saves a drawing to disk for the given document ID
    func saveDrawing(_ drawing: PKDrawing, for documentID: UUID) throws {
        let url = getDrawingURL(for: documentID)
        let data = drawing.dataRepresentation()
        try data.write(to: url)
    }

    /// Loads a drawing from disk for the given document ID
    /// Returns nil if no drawing exists or if loading fails
    func loadDrawing(for documentID: UUID) -> PKDrawing? {
        let url = getDrawingURL(for: documentID)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        return drawing
    }

    /// Deletes the drawing file for the given document ID
    func deleteDrawing(for documentID: UUID) {
        let url = getDrawingURL(for: documentID)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Checks if a drawing exists for the given document ID
    func drawingExists(for documentID: UUID) -> Bool {
        fileManager.fileExists(atPath: getDrawingURL(for: documentID).path)
    }

    // MARK: - Private

    private func getDrawingURL(for documentID: UUID) -> URL {
        drawingsDirectory.appendingPathComponent("\(documentID.uuidString).drawing")
    }
}
