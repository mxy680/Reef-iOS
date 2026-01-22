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

        var totalMigrated = 0

        for course in courses {
            // Process materials
            let unindexedMaterials = course.materials.filter {
                !$0.isVectorIndexed && $0.extractedText != nil
            }

            if !unindexedMaterials.isEmpty {
                print("[Migration] Found \(unindexedMaterials.count) unindexed materials in '\(course.name)'")
            }

            for batch in unindexedMaterials.chunked(into: batchSize) {
                await processBatch(batch, courseId: course.id, type: .material)
                totalMigrated += batch.count
            }

            // Process assignments
            let unindexedAssignments = course.assignments.filter {
                !$0.isVectorIndexed && $0.extractedText != nil
            }

            if !unindexedAssignments.isEmpty {
                print("[Migration] Found \(unindexedAssignments.count) unindexed assignments in '\(course.name)'")
            }

            for batch in unindexedAssignments.chunked(into: batchSize) {
                await processBatch(batch, courseId: course.id, type: .assignment)
                totalMigrated += batch.count
            }
        }

        if totalMigrated > 0 {
            print("[Migration] Completed migration of \(totalMigrated) documents")
        } else {
            print("[Migration] No documents needed migration")
        }
    }

    /// Process a batch of materials
    @MainActor
    private func processBatch(_ materials: [Material], courseId: UUID, type: DocumentType) async {
        for material in materials {
            guard let text = material.extractedText else { continue }

            do {
                try await RAGService.shared.indexDocument(
                    documentId: material.id,
                    documentType: type,
                    courseId: courseId,
                    text: text
                )
                material.isVectorIndexed = true
                print("[Migration] Indexed material: \(material.name)")
            } catch {
                print("[Migration] Failed to index material \(material.name): \(error)")
            }

            // Small delay between documents to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    /// Process a batch of assignments
    @MainActor
    private func processBatch(_ assignments: [Assignment], courseId: UUID, type: DocumentType) async {
        for assignment in assignments {
            guard let text = assignment.extractedText else { continue }

            do {
                try await RAGService.shared.indexDocument(
                    documentId: assignment.id,
                    documentType: type,
                    courseId: courseId,
                    text: text
                )
                assignment.isVectorIndexed = true
                print("[Migration] Indexed assignment: \(assignment.name)")
            } catch {
                print("[Migration] Failed to index assignment \(assignment.name): \(error)")
            }

            // Small delay between documents
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
