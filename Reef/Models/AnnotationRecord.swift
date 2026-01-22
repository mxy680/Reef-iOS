//
//  AnnotationRecord.swift
//  Reef
//
//  SwiftData model for storing annotations and version history

import Foundation
import SwiftData
import PencilKit

@Model
class AnnotationRecord {
    var id: UUID = UUID()
    var documentId: UUID                    // Links to Material or Assignment
    var documentType: String                // "material", "assignment", "blank"
    var lastModified: Date = Date()

    // Store drawings as serialized data (one per page)
    var drawingsData: Data?                 // Serialized [PageDrawing]

    // Version history (last 20 versions)
    var versionsData: Data?                 // Serialized [AnnotationVersion]

    init(documentId: UUID, documentType: DocumentType) {
        self.documentId = documentId
        self.documentType = documentType.rawValue
    }

    // MARK: - Document Type

    enum DocumentType: String, Codable {
        case material
        case assignment
        case blank
    }

    var type: DocumentType {
        get { DocumentType(rawValue: documentType) ?? .material }
        set { documentType = newValue.rawValue }
    }

    // MARK: - Drawings Access

    var drawings: [PageDrawing] {
        get {
            guard let data = drawingsData else { return [] }
            return (try? JSONDecoder().decode([PageDrawing].self, from: data)) ?? []
        }
        set {
            drawingsData = try? JSONEncoder().encode(newValue)
        }
    }

    func getDrawing(for pageIndex: Int) -> PKDrawing {
        if let pageDrawing = drawings.first(where: { $0.pageIndex == pageIndex }),
           let drawing = PKDrawing.deserialize(from: pageDrawing.drawingData) {
            return drawing
        }
        return PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int) {
        var currentDrawings = drawings
        let drawingData = drawing.serialize()

        if let index = currentDrawings.firstIndex(where: { $0.pageIndex == pageIndex }) {
            currentDrawings[index] = PageDrawing(pageIndex: pageIndex, drawingData: drawingData)
        } else {
            currentDrawings.append(PageDrawing(pageIndex: pageIndex, drawingData: drawingData))
        }

        drawings = currentDrawings
        lastModified = Date()
    }

    // MARK: - Version History

    private static let maxVersions = 20

    var versions: [AnnotationVersion] {
        get {
            guard let data = versionsData else { return [] }
            return (try? JSONDecoder().decode([AnnotationVersion].self, from: data)) ?? []
        }
        set {
            versionsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Creates a new version snapshot of the current drawings
    func createVersionSnapshot() {
        var currentVersions = versions

        let newVersion = AnnotationVersion(
            id: UUID(),
            drawings: drawings,
            timestamp: Date()
        )

        currentVersions.insert(newVersion, at: 0)

        // Keep only the last 20 versions
        if currentVersions.count > Self.maxVersions {
            currentVersions = Array(currentVersions.prefix(Self.maxVersions))
        }

        versions = currentVersions
    }

    /// Restores drawings from a specific version
    /// - Parameter versionId: The ID of the version to restore
    /// - Returns: true if successful
    func restoreVersion(_ versionId: UUID) -> Bool {
        guard let version = versions.first(where: { $0.id == versionId }) else {
            return false
        }

        // Save current state as a new version before restoring
        createVersionSnapshot()

        // Restore the drawings from the selected version
        drawings = version.drawings
        lastModified = Date()

        return true
    }
}

// MARK: - Page Drawing

struct PageDrawing: Codable, Equatable {
    let pageIndex: Int
    let drawingData: Data     // Serialized PKDrawing

    init(pageIndex: Int, drawingData: Data) {
        self.pageIndex = pageIndex
        self.drawingData = drawingData
    }
}

// MARK: - Annotation Version

struct AnnotationVersion: Codable, Identifiable {
    let id: UUID
    let drawings: [PageDrawing]
    let timestamp: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - PKDrawing Serialization

extension PKDrawing {
    /// Serializes the drawing to Data for storage
    func serialize() -> Data {
        dataRepresentation()
    }

    /// Deserializes drawing from Data
    static func deserialize(from data: Data) -> PKDrawing? {
        try? PKDrawing(data: data)
    }
}
