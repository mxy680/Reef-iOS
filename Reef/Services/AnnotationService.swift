//
//  AnnotationService.swift
//  Reef
//
//  Service for managing annotation persistence with auto-save and version history

import Foundation
import SwiftUI
import SwiftData
import PencilKit

@MainActor
class AnnotationService: ObservableObject {
    private let modelContext: ModelContext
    private var autoSaveTask: Task<Void, Never>?
    private let autoSaveDebounce: UInt64 = 2_000_000_000 // 2 seconds

    // Track if we need to create a version snapshot
    private var pendingVersionSnapshot: Bool = false
    private var lastVersionTimestamp: Date?
    private let versionSnapshotInterval: TimeInterval = 60 // Create version every 60 seconds of changes

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load/Create Annotation Record

    /// Fetches or creates an AnnotationRecord for the given document
    func getOrCreateRecord(for documentId: UUID, documentType: AnnotationRecord.DocumentType) -> AnnotationRecord {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.documentId == documentId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // Create new record
        let record = AnnotationRecord(documentId: documentId, documentType: documentType)
        modelContext.insert(record)
        return record
    }

    /// Fetches an existing AnnotationRecord for the given document
    func getRecord(for documentId: UUID) -> AnnotationRecord? {
        let descriptor = FetchDescriptor<AnnotationRecord>(
            predicate: #Predicate { $0.documentId == documentId }
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Save Operations

    /// Schedules an auto-save with debouncing
    func scheduleAutoSave(for record: AnnotationRecord) {
        autoSaveTask?.cancel()

        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: autoSaveDebounce)

            if !Task.isCancelled {
                save(record: record)
            }
        }
    }

    /// Immediately saves the annotation record
    func save(record: AnnotationRecord) {
        record.lastModified = Date()

        // Check if we should create a version snapshot
        if shouldCreateVersionSnapshot() {
            record.createVersionSnapshot()
            lastVersionTimestamp = Date()
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save annotation record: \(error)")
        }
    }

    /// Forces a version snapshot to be created on next save
    func markForVersionSnapshot() {
        pendingVersionSnapshot = true
    }

    private func shouldCreateVersionSnapshot() -> Bool {
        if pendingVersionSnapshot {
            pendingVersionSnapshot = false
            return true
        }

        guard let lastTimestamp = lastVersionTimestamp else {
            lastVersionTimestamp = Date()
            return true // First save, create initial version
        }

        return Date().timeIntervalSince(lastTimestamp) >= versionSnapshotInterval
    }

    // MARK: - Version History

    /// Restores a specific version
    func restoreVersion(_ versionId: UUID, for record: AnnotationRecord) -> Bool {
        let success = record.restoreVersion(versionId)
        if success {
            save(record: record)
        }
        return success
    }

    /// Gets all versions for a record
    func getVersions(for record: AnnotationRecord) -> [AnnotationVersion] {
        record.versions
    }

    // MARK: - Delete Operations

    /// Deletes the annotation record for a document
    func deleteRecord(for documentId: UUID) {
        if let record = getRecord(for: documentId) {
            modelContext.delete(record)
            try? modelContext.save()
        }
    }

    // MARK: - Drawing Operations

    /// Gets the drawing for a specific page
    func getDrawing(for pageIndex: Int, record: AnnotationRecord) -> PKDrawing {
        record.getDrawing(for: pageIndex)
    }

    /// Sets the drawing for a specific page and schedules auto-save
    func setDrawing(_ drawing: PKDrawing, for pageIndex: Int, record: AnnotationRecord) {
        record.setDrawing(drawing, for: pageIndex)
        scheduleAutoSave(for: record)
    }

    // MARK: - All Drawings

    /// Gets all drawings as a dictionary of page index to PKDrawing
    func getAllDrawings(for record: AnnotationRecord) -> [Int: PKDrawing] {
        var result: [Int: PKDrawing] = [:]
        for pageDrawing in record.drawings {
            if let drawing = PKDrawing.deserialize(from: pageDrawing.drawingData) {
                result[pageDrawing.pageIndex] = drawing
            }
        }
        return result
    }

    /// Sets all drawings from a dictionary
    func setAllDrawings(_ drawings: [Int: PKDrawing], for record: AnnotationRecord) {
        for (pageIndex, drawing) in drawings {
            record.setDrawing(drawing, for: pageIndex)
        }
        save(record: record)
    }
}

// MARK: - Annotation Service Provider

/// Environment key for AnnotationService
struct AnnotationServiceKey: EnvironmentKey {
    static let defaultValue: AnnotationService? = nil
}

extension EnvironmentValues {
    var annotationService: AnnotationService? {
        get { self[AnnotationServiceKey.self] }
        set { self[AnnotationServiceKey.self] = newValue }
    }
}
