//
//  VectorStore.swift
//  Reef
//
//  SQLite-based vector storage for semantic search.
//  Stores text chunks with their embeddings and supports cosine similarity search.
//

import Foundation
import SQLite3
import Accelerate

/// A search result with similarity score
struct VectorSearchResult: Identifiable {
    let id: String
    let text: String
    let documentId: UUID
    let documentType: DocumentType
    let pageNumber: Int?
    let heading: String?
    let similarity: Float

    var sourceDescription: String {
        var parts: [String] = []
        if let heading = heading {
            parts.append(heading)
        }
        if let page = pageNumber {
            parts.append("Page \(page)")
        }
        return parts.isEmpty ? "Document" : parts.joined(separator: " - ")
    }
}

/// Errors that can occur in VectorStore operations
enum VectorStoreError: Error, LocalizedError {
    case databaseError(String)
    case invalidEmbedding
    case chunkNotFound

    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidEmbedding:
            return "Invalid embedding data"
        case .chunkNotFound:
            return "Chunk not found"
        }
    }
}

/// Actor-based SQLite vector store
actor VectorStore {
    static let shared = VectorStore()

    private var db: OpaquePointer?
    private let dbPath: URL

    /// Track whether a version migration occurred (for triggering re-indexing)
    private(set) var didMigrateVersion = false

    init(dbPath: URL? = nil) {
        if let dbPath = dbPath {
            self.dbPath = dbPath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let reefDir = appSupport.appendingPathComponent("Reef", isDirectory: true)
            try? FileManager.default.createDirectory(at: reefDir, withIntermediateDirectories: true)
            self.dbPath = reefDir.appendingPathComponent("vectors.sqlite")
        }
    }

    // MARK: - Database Setup

    /// Initialize the database (call on app launch)
    func initialize() throws {
        guard db == nil else { return }

        var dbPointer: OpaquePointer?
        let result = sqlite3_open(dbPath.path, &dbPointer)

        guard result == SQLITE_OK, let pointer = dbPointer else {
            let errorMessage = String(cString: sqlite3_errmsg(dbPointer))
            sqlite3_close(dbPointer)
            throw VectorStoreError.databaseError("Failed to open database: \(errorMessage)")
        }

        self.db = pointer
        try createTables()
        try checkAndMigrateVersion()
    }

    private func createTables() throws {
        let createSQL = """
            CREATE TABLE IF NOT EXISTS chunks (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                document_type TEXT NOT NULL,
                position INTEGER,
                page_number INTEGER,
                heading TEXT,
                text TEXT NOT NULL,
                embedding BLOB NOT NULL,
                created_at REAL DEFAULT (julianday('now'))
            );

            CREATE INDEX IF NOT EXISTS idx_chunks_course ON chunks(course_id);
            CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);

            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_run(db, createSQL, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw VectorStoreError.databaseError("Failed to create tables: \(error)")
        }
    }

    /// Check embedding version and clear chunks if version changed
    private func checkAndMigrateVersion() throws {
        guard let db = db else { return }

        let currentVersion = EmbeddingService.embeddingVersion

        // Get stored version
        let selectSQL = "SELECT value FROM metadata WHERE key = 'embedding_version'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare version query")
        }
        defer { sqlite3_finalize(statement) }

        var storedVersion: Int? = nil
        if sqlite3_step(statement) == SQLITE_ROW {
            if let valueCStr = sqlite3_column_text(statement, 0) {
                storedVersion = Int(String(cString: valueCStr))
            }
        }

        // Check if version changed
        if let stored = storedVersion, stored == currentVersion {
            print("[VectorStore] Embedding version \(currentVersion) matches stored version")
            return
        }

        // Version changed or not set - clear all chunks and update version
        if let stored = storedVersion {
            print("[VectorStore] Embedding version changed from \(stored) to \(currentVersion) - clearing all chunks")
        } else {
            print("[VectorStore] Setting embedding version to \(currentVersion)")
        }

        // Clear all chunks
        var errorMessage: UnsafeMutablePointer<CChar>?
        sqlite3_run(db, "DELETE FROM chunks", nil, nil, &errorMessage)

        // Update version
        let updateSQL = "INSERT OR REPLACE INTO metadata (key, value) VALUES ('embedding_version', ?)"
        var updateStmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare version update")
        }
        defer { sqlite3_finalize(updateStmt) }

        sqlite3_bind_text(updateStmt, 1, String(currentVersion), -1, SQLITE_TRANSIENT)

        if sqlite3_step(updateStmt) != SQLITE_DONE {
            throw VectorStoreError.databaseError("Failed to update embedding version")
        }

        // Mark that migration occurred
        if storedVersion != nil {
            didMigrateVersion = true
        }
    }

    // MARK: - Indexing

    /// Store chunks with their embeddings
    /// - Parameters:
    ///   - chunks: Text chunks to store
    ///   - embeddings: Corresponding embeddings (must match chunks count)
    ///   - courseId: The course ID to scope the chunks
    func index(
        chunks: [TextChunk],
        embeddings: [[Float]],
        courseId: UUID
    ) throws {
        guard chunks.count == embeddings.count else {
            throw VectorStoreError.databaseError("Chunks and embeddings count mismatch")
        }

        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        let insertSQL = """
            INSERT OR REPLACE INTO chunks
            (id, course_id, document_id, document_type, position, page_number, heading, text, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare insert statement")
        }
        defer { sqlite3_finalize(statement) }

        // Begin transaction for performance
        sqlite3_run(db, "BEGIN TRANSACTION", nil, nil, nil)

        for (chunk, embedding) in zip(chunks, embeddings) {
            sqlite3_reset(statement)

            // Bind parameters
            sqlite3_bind_text(statement, 1, chunk.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, courseId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, chunk.documentId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, chunk.documentType.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 5, Int32(chunk.position))

            if let pageNumber = chunk.pageNumber {
                sqlite3_bind_int(statement, 6, Int32(pageNumber))
            } else {
                sqlite3_bind_null(statement, 6)
            }

            if let heading = chunk.heading {
                sqlite3_bind_text(statement, 7, heading, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 7)
            }

            sqlite3_bind_text(statement, 8, chunk.text, -1, SQLITE_TRANSIENT)

            // Convert embedding to Data
            let embeddingData = embedding.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            _ = embeddingData.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 9, bytes.baseAddress, Int32(embeddingData.count), SQLITE_TRANSIENT)
            }

            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                sqlite3_run(db, "ROLLBACK", nil, nil, nil)
                throw VectorStoreError.databaseError("Failed to insert chunk: \(String(cString: sqlite3_errmsg(db)))")
            }
        }

        sqlite3_run(db, "COMMIT", nil, nil, nil)
    }

    // MARK: - Search

    /// Search for similar chunks using cosine similarity
    /// - Parameters:
    ///   - queryEmbedding: The embedding of the search query
    ///   - courseId: Course ID to scope the search
    ///   - topK: Maximum number of results to return
    /// - Returns: Array of search results sorted by similarity (descending)
    func search(
        query queryEmbedding: [Float],
        courseId: UUID,
        topK: Int = 5
    ) throws -> [VectorSearchResult] {
        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        let expectedDimension = EmbeddingService.embeddingDimension

        let selectSQL = """
            SELECT id, document_id, document_type, page_number, heading, text, embedding
            FROM chunks
            WHERE course_id = ?
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare select statement")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, courseId.uuidString, -1, SQLITE_TRANSIENT)

        var results: [VectorSearchResult] = []
        var skippedCount = 0

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCStr = sqlite3_column_text(statement, 0),
                  let docIdCStr = sqlite3_column_text(statement, 1),
                  let docTypeCStr = sqlite3_column_text(statement, 2),
                  let textCStr = sqlite3_column_text(statement, 5) else {
                continue
            }

            let id = String(cString: idCStr)
            let documentId = UUID(uuidString: String(cString: docIdCStr)) ?? UUID()
            let documentType = DocumentType(rawValue: String(cString: docTypeCStr)) ?? .note
            let text = String(cString: textCStr)

            let pageNumber: Int? = sqlite3_column_type(statement, 3) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 3))
                : nil

            let heading: String? = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 4))
                : nil

            // Get embedding blob
            guard let blobPointer = sqlite3_column_blob(statement, 6) else { continue }
            let blobSize = Int(sqlite3_column_bytes(statement, 6))
            let floatCount = blobSize / MemoryLayout<Float>.size

            // Skip chunks with dimension mismatch (graceful fallback during migration)
            if floatCount != expectedDimension {
                skippedCount += 1
                continue
            }

            let embedding = Array(UnsafeBufferPointer(
                start: blobPointer.assumingMemoryBound(to: Float.self),
                count: floatCount
            ))

            // Calculate cosine similarity using Accelerate
            let similarity = cosineSimilarity(queryEmbedding, embedding)

            results.append(VectorSearchResult(
                id: id,
                text: text,
                documentId: documentId,
                documentType: documentType,
                pageNumber: pageNumber,
                heading: heading,
                similarity: similarity
            ))
        }

        if skippedCount > 0 {
            print("[VectorStore] Skipped \(skippedCount) chunks with dimension mismatch")
        }

        // Sort by similarity (descending) and take top K
        return Array(results.sorted { $0.similarity > $1.similarity }.prefix(topK))
    }

    // MARK: - Deletion

    /// Delete all chunks for a document
    func deleteDocument(documentId: UUID) throws {
        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        let deleteSQL = "DELETE FROM chunks WHERE document_id = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare delete statement")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, documentId.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw VectorStoreError.databaseError("Failed to delete document chunks")
        }
    }

    /// Delete all chunks for a course
    func deleteCourse(courseId: UUID) throws {
        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        let deleteSQL = "DELETE FROM chunks WHERE course_id = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare delete statement")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, courseId.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw VectorStoreError.databaseError("Failed to delete course chunks")
        }
    }

    /// Delete all chunks (for migration)
    func deleteAllChunks() throws {
        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_run(db, "DELETE FROM chunks", nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw VectorStoreError.databaseError("Failed to delete all chunks: \(error)")
        }

        print("[VectorStore] Deleted all chunks")
    }

    /// Get count of indexed chunks for a document
    func chunkCount(forDocument documentId: UUID) throws -> Int {
        guard let db = db else {
            throw VectorStoreError.databaseError("Database not initialized")
        }

        let countSQL = "SELECT COUNT(*) FROM chunks WHERE document_id = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare count statement")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, documentId.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }

        return 0
    }

    // MARK: - Cleanup

    /// Close the database connection
    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Private Helpers

    /// Calculate cosine similarity using Accelerate framework
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use Accelerate for SIMD-optimized computation
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}

// MARK: - SQLite Helpers

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Wrapper for sqlite3_exec to avoid naming conflicts
@discardableResult
private func sqlite3_run(
    _ db: OpaquePointer?,
    _ sql: String,
    _ callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
    _ context: UnsafeMutableRawPointer?,
    _ errorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    return sqlite3_exec(db, sql, callback, context, errorMessage)
}
