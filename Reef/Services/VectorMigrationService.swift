//
//  VectorMigrationService.swift
//  Reef
//
//  Handles migration of existing documents to the vector index.
//  Processes documents that have extracted text but haven't been indexed yet.
//

import Foundation
import SwiftData

/// Service for migrating existing documents to the vector index
struct VectorMigrationService {
    /// Batch size for processing documents
    private let batchSize = 5

    /// Migrate all unindexed documents with extracted text
    /// - Parameter courses: All courses to process
    @MainActor
    func migrateIfNeeded(courses: [Course]) async {
        print("[Migration] Starting vector index migration check...")

        // Check if embedding version changed - if so, reset all isVectorIndexed flags
        let didVersionChange = await VectorStore.shared.didMigrateVersion
        if didVersionChange {
            print("[Migration] Embedding version changed - resetting all vector index flags")
            resetAllVectorIndexFlags(courses: courses)
        }

        var totalMigrated = 0

        for course in courses {
            // Process notes
            let unindexedNotes = course.notes.filter {
                !$0.isVectorIndexed && $0.extractedText != nil
            }

            if !unindexedNotes.isEmpty {
                print("[Migration] Found \(unindexedNotes.count) unindexed notes in '\(course.name)'")
            }

            for batch in unindexedNotes.chunked(into: batchSize) {
                await processBatch(batch, courseId: course.id, type: .note)
                totalMigrated += batch.count
            }
        }

        if totalMigrated > 0 {
            print("[Migration] Completed migration of \(totalMigrated) documents")
        } else {
            print("[Migration] No documents needed migration")
        }
    }

    /// Reset isVectorIndexed flag on all notes when embedding version changes
    @MainActor
    private func resetAllVectorIndexFlags(courses: [Course]) {
        var resetCount = 0

        for course in courses {
            for note in course.notes {
                if note.isVectorIndexed {
                    note.isVectorIndexed = false
                    resetCount += 1
                }
            }
        }

        print("[Migration] Reset vector index flag on \(resetCount) documents")
    }

    /// Process a batch of notes
    @MainActor
    private func processBatch(_ notes: [Note], courseId: UUID, type: DocumentType) async {
        for note in notes {
            guard let text = note.extractedText else { continue }

            do {
                try await RAGService.shared.indexDocument(
                    documentId: note.id,
                    documentType: type,
                    courseId: courseId,
                    text: text
                )
                note.isVectorIndexed = true
                print("[Migration] Indexed note: \(note.name)")
            } catch {
                print("[Migration] Failed to index note \(note.name): \(error)")
            }

            // Small delay between documents to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
