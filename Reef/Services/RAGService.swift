//
//  RAGService.swift
//  Reef
//
//  Orchestrates Retrieval Augmented Generation (RAG) for AI features.
//  Handles document indexing and context retrieval for the Live AI Feedback feature.
//

import Foundation

/// Context retrieved from the vector database for RAG
struct RAGContext {
    /// Formatted prompt to inject into AI request
    let formattedPrompt: String

    /// Number of chunks used
    let chunkCount: Int

    /// Source documents referenced
    let sources: [RAGSource]

    /// Whether any context was found
    var hasContext: Bool { chunkCount > 0 }
}

/// A source document referenced in RAG context
struct RAGSource: Identifiable {
    let id: String
    let documentId: UUID
    let documentType: DocumentType
    let heading: String?
    let pageNumber: Int?
    let similarity: Float

    var description: String {
        var parts: [String] = []
        if let heading = heading {
            parts.append(heading)
        }
        if let page = pageNumber {
            parts.append("Page \(page)")
        }
        if parts.isEmpty {
            return documentType == .note ? "Notes" : "Assignment"
        }
        return parts.joined(separator: " - ")
    }
}

/// Service for orchestrating RAG operations
actor RAGService {
    static let shared = RAGService()

    /// Approximate tokens per character (conservative estimate)
    private let charsPerToken: Double = 4.0

    private init() {}

    // MARK: - Initialization

    /// Initialize the RAG system (call on app launch)
    func initialize() async throws {
        // Initialize embedding service first (loads tokenizer + CoreML model)
        try await EmbeddingService.shared.initialize()

        // Then initialize vector store (checks embedding version and clears if changed)
        try await VectorStore.shared.initialize()
    }

    // MARK: - Document Indexing

    /// Index a document for RAG retrieval
    /// - Parameters:
    ///   - documentId: UUID of the document
    ///   - documentType: Type of document (.note or .assignment)
    ///   - courseId: The course this document belongs to
    ///   - text: Full text content of the document
    func indexDocument(
        documentId: UUID,
        documentType: DocumentType,
        courseId: UUID,
        text: String
    ) async throws {
        // Skip if text is too short to be meaningful
        guard text.count >= TextChunker.minChunkSize else {
            print("[RAG] Skipping indexing - text too short (\(text.count) chars)")
            return
        }

        // Check if embedding service is available
        guard await EmbeddingService.shared.isAvailable() else {
            print("[RAG] Embedding service not available, skipping indexing")
            return
        }

        // Chunk the text
        let chunks = TextChunker.chunk(
            text: text,
            documentId: documentId,
            documentType: documentType
        )

        guard !chunks.isEmpty else {
            print("[RAG] No chunks generated from text")
            return
        }

        print("[RAG] Indexing \(chunks.count) chunks for document \(documentId)")

        // Generate embeddings for all chunks
        let chunkTexts = chunks.map { $0.text }
        let embeddings = try await EmbeddingService.shared.embedBatch(chunkTexts)

        // Store in vector database
        try await VectorStore.shared.index(
            chunks: chunks,
            embeddings: embeddings,
            courseId: courseId
        )

        print("[RAG] Successfully indexed document \(documentId)")
    }

    // MARK: - Context Retrieval

    /// Get relevant context for a query
    /// - Parameters:
    ///   - query: The user's query or current work context
    ///   - courseId: Course ID to scope the search
    ///   - topK: Maximum number of chunks to retrieve
    ///   - maxTokens: Maximum tokens in the context (approximate)
    /// - Returns: RAGContext with formatted prompt and sources
    func getContext(
        query: String,
        courseId: UUID,
        topK: Int = 5,
        maxTokens: Int = 2000
    ) async throws -> RAGContext {
        // Check if embedding service is available
        guard await EmbeddingService.shared.isAvailable() else {
            return RAGContext(formattedPrompt: "", chunkCount: 0, sources: [])
        }

        // Embed the query
        let queryEmbedding = try await EmbeddingService.shared.embed(query)

        // Search for relevant chunks
        let results = try await VectorStore.shared.search(
            query: queryEmbedding,
            courseId: courseId,
            topK: topK
        )

        guard !results.isEmpty else {
            return RAGContext(formattedPrompt: "", chunkCount: 0, sources: [])
        }

        // Build context within token budget
        let maxChars = Int(Double(maxTokens) * charsPerToken)
        var contextParts: [String] = []
        var totalChars = 0
        var sources: [RAGSource] = []

        // Debug: log similarity scores
        print("[RAG] Search returned \(results.count) results:")
        for (i, r) in results.prefix(5).enumerated() {
            print("[RAG]   \(i+1). similarity=\(r.similarity) - \(r.text.prefix(50))...")
        }

        for result in results {
            // Skip low-similarity results (lowered threshold for MiniLM)
            guard result.similarity > 0.15 else { continue }

            // Check token budget
            let chunkChars = result.text.count + 50 // Extra for formatting
            if totalChars + chunkChars > maxChars {
                break
            }

            // Add to context
            let sourceLabel = result.sourceDescription
            contextParts.append("[\(sourceLabel)]\n\(result.text)")
            totalChars += chunkChars

            sources.append(RAGSource(
                id: result.id,
                documentId: result.documentId,
                documentType: result.documentType,
                heading: result.heading,
                pageNumber: result.pageNumber,
                similarity: result.similarity
            ))
        }

        guard !contextParts.isEmpty else {
            return RAGContext(formattedPrompt: "", chunkCount: 0, sources: [])
        }

        // Format the prompt
        let formattedPrompt = """
            The following is relevant context from the student's course materials:

            ---
            \(contextParts.joined(separator: "\n\n---\n\n"))
            ---

            Use this context to provide accurate, relevant assistance. Reference specific sections when helpful.
            """

        return RAGContext(
            formattedPrompt: formattedPrompt,
            chunkCount: sources.count,
            sources: sources
        )
    }

    // MARK: - Deletion

    /// Remove a document from the index
    func deleteDocument(documentId: UUID) async throws {
        try await VectorStore.shared.deleteDocument(documentId: documentId)
        print("[RAG] Deleted document \(documentId) from index")
    }

    /// Remove all documents for a course from the index
    func deleteCourse(courseId: UUID) async throws {
        try await VectorStore.shared.deleteCourse(courseId: courseId)
        print("[RAG] Deleted course \(courseId) from index")
    }

    // MARK: - Status

    /// Check if a document has been indexed
    func isDocumentIndexed(documentId: UUID) async -> Bool {
        do {
            let count = try await VectorStore.shared.chunkCount(forDocument: documentId)
            return count > 0
        } catch {
            return false
        }
    }

    /// Get the number of indexed chunks for a document
    func chunkCount(forDocument documentId: UUID) async -> Int {
        do {
            return try await VectorStore.shared.chunkCount(forDocument: documentId)
        } catch {
            return 0
        }
    }
}
