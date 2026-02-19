//
//  ModelTests.swift
//  ReefTests
//
//  Tests for data model computed properties and initializers.
//  Covers: TextChunk, DocumentType, VectorSearchResult, RAGSource,
//          RAGContext, AIServiceError, VectorStoreError, EmbeddingError.
//

import Testing
import Foundation
@testable import Reef

@Suite("Data Models", .serialized)
struct ModelTests {

    // MARK: - TextChunk

    @Suite("TextChunk")
    struct TextChunkTests {

        private let docId = UUID(uuidString: "AABBCCDD-AABB-AABB-AABB-AABBCCDDEEFF")!

        @Test("ID format is documentId.uuidString-position")
        func idFormat() {
            let chunk = TextChunk(
                text: "Hello world",
                documentId: docId,
                documentType: .note,
                position: 3
            )
            #expect(chunk.id == "\(docId.uuidString)-3")
        }

        @Test("Position zero produces correct ID")
        func idFormatPositionZero() {
            let chunk = TextChunk(
                text: "Some text",
                documentId: docId,
                documentType: .note,
                position: 0
            )
            #expect(chunk.id == "\(docId.uuidString)-0")
        }

        @Test("pageNumber defaults to nil when not provided")
        func pageNumberDefaultsToNil() {
            let chunk = TextChunk(
                text: "Some text",
                documentId: docId,
                documentType: .note,
                position: 0
            )
            #expect(chunk.pageNumber == nil)
        }

        @Test("heading defaults to nil when not provided")
        func headingDefaultsToNil() {
            let chunk = TextChunk(
                text: "Some text",
                documentId: docId,
                documentType: .note,
                position: 0
            )
            #expect(chunk.heading == nil)
        }

        @Test("All fields stored correctly")
        func allFieldsStored() {
            let chunk = TextChunk(
                text: "Chapter content here",
                documentId: docId,
                documentType: .assignment,
                position: 7,
                pageNumber: 4,
                heading: "Introduction"
            )
            #expect(chunk.text == "Chapter content here")
            #expect(chunk.documentId == docId)
            #expect(chunk.documentType == .assignment)
            #expect(chunk.position == 7)
            #expect(chunk.pageNumber == 4)
            #expect(chunk.heading == "Introduction")
        }

        @Test("Different positions produce different IDs for same documentId")
        func differentPositionsDifferentIds() {
            let chunk0 = TextChunk(text: "A", documentId: docId, documentType: .note, position: 0)
            let chunk1 = TextChunk(text: "B", documentId: docId, documentType: .note, position: 1)
            #expect(chunk0.id != chunk1.id)
            #expect(chunk0.id == "\(docId.uuidString)-0")
            #expect(chunk1.id == "\(docId.uuidString)-1")
        }
    }

    // MARK: - DocumentType

    @Suite("DocumentType")
    struct DocumentTypeTests {

        @Test("note raw value is 'note'")
        func noteRawValue() {
            #expect(DocumentType.note.rawValue == "note")
        }

        @Test("assignment raw value is 'assignment'")
        func assignmentRawValue() {
            #expect(DocumentType.assignment.rawValue == "assignment")
        }

        @Test("Initializes from raw value 'note'")
        func initFromNoteRawValue() {
            #expect(DocumentType(rawValue: "note") == .note)
        }

        @Test("Initializes from raw value 'assignment'")
        func initFromAssignmentRawValue() {
            #expect(DocumentType(rawValue: "assignment") == .assignment)
        }

        @Test("Returns nil for unknown raw value")
        func nilForUnknownRawValue() {
            #expect(DocumentType(rawValue: "unknown") == nil)
        }
    }

    // MARK: - VectorSearchResult

    @Suite("VectorSearchResult")
    struct VectorSearchResultTests {

        private let docId = UUID()

        private func makeResult(heading: String?, pageNumber: Int?) -> VectorSearchResult {
            VectorSearchResult(
                id: "test-id",
                text: "Some text",
                documentId: docId,
                documentType: .note,
                pageNumber: pageNumber,
                heading: heading,
                similarity: 0.9
            )
        }

        @Test("sourceDescription is 'Heading - Page N' when both heading and page present")
        func sourceDescriptionHeadingAndPage() {
            let result = makeResult(heading: "Introduction", pageNumber: 3)
            #expect(result.sourceDescription == "Introduction - Page 3")
        }

        @Test("sourceDescription is heading only when no page number")
        func sourceDescriptionHeadingOnly() {
            let result = makeResult(heading: "Methods", pageNumber: nil)
            #expect(result.sourceDescription == "Methods")
        }

        @Test("sourceDescription is 'Page N' only when no heading")
        func sourceDescriptionPageOnly() {
            let result = makeResult(heading: nil, pageNumber: 5)
            #expect(result.sourceDescription == "Page 5")
        }

        @Test("sourceDescription is 'Document' when both heading and page are nil")
        func sourceDescriptionDocument() {
            let result = makeResult(heading: nil, pageNumber: nil)
            #expect(result.sourceDescription == "Document")
        }

        @Test("sourceDescription uses page number 1")
        func sourceDescriptionPageOne() {
            let result = makeResult(heading: nil, pageNumber: 1)
            #expect(result.sourceDescription == "Page 1")
        }
    }

    // MARK: - RAGSource

    @Suite("RAGSource")
    struct RAGSourceTests {

        private let docId = UUID()

        private func makeSource(
            documentType: DocumentType,
            heading: String?,
            pageNumber: Int?
        ) -> RAGSource {
            RAGSource(
                id: "src-id",
                documentId: docId,
                documentType: documentType,
                heading: heading,
                pageNumber: pageNumber,
                similarity: 0.85
            )
        }

        @Test("description is 'Heading - Page N' when both present")
        func descriptionHeadingAndPage() {
            let source = makeSource(documentType: .note, heading: "Summary", pageNumber: 2)
            #expect(source.description == "Summary - Page 2")
        }

        @Test("description is heading only when no page number")
        func descriptionHeadingOnly() {
            let source = makeSource(documentType: .note, heading: "Background", pageNumber: nil)
            #expect(source.description == "Background")
        }

        @Test("description is 'Page N' only when no heading")
        func descriptionPageOnly() {
            let source = makeSource(documentType: .note, heading: nil, pageNumber: 7)
            #expect(source.description == "Page 7")
        }

        @Test("description is 'Notes' for .note when both heading and page are nil")
        func descriptionFallbackNote() {
            let source = makeSource(documentType: .note, heading: nil, pageNumber: nil)
            #expect(source.description == "Notes")
        }

        @Test("description is 'Assignment' for .assignment when both heading and page are nil")
        func descriptionFallbackAssignment() {
            let source = makeSource(documentType: .assignment, heading: nil, pageNumber: nil)
            #expect(source.description == "Assignment")
        }

        @Test("description uses .assignment type with heading and page")
        func descriptionAssignmentWithMetadata() {
            let source = makeSource(documentType: .assignment, heading: "Problem 1", pageNumber: 3)
            #expect(source.description == "Problem 1 - Page 3")
        }
    }

    // MARK: - RAGContext

    @Suite("RAGContext")
    struct RAGContextTests {

        @Test("hasContext is true when chunkCount greater than zero")
        func hasContextTrueWhenChunksPresent() {
            let context = RAGContext(formattedPrompt: "some context", chunkCount: 1, sources: [])
            #expect(context.hasContext == true)
        }

        @Test("hasContext is true when chunkCount is large")
        func hasContextTrueForMultipleChunks() {
            let context = RAGContext(formattedPrompt: "context", chunkCount: 5, sources: [])
            #expect(context.hasContext == true)
        }

        @Test("hasContext is false when chunkCount is zero")
        func hasContextFalseWhenNoChunks() {
            let context = RAGContext(formattedPrompt: "", chunkCount: 0, sources: [])
            #expect(context.hasContext == false)
        }

        @Test("chunkCount stored correctly")
        func chunkCountStored() {
            let context = RAGContext(formattedPrompt: "prompt", chunkCount: 3, sources: [])
            #expect(context.chunkCount == 3)
        }
    }

    // MARK: - AIServiceError

    @Suite("AIServiceError")
    struct AIServiceErrorTests {

        @Test("invalidURL errorDescription")
        func invalidURLDescription() {
            let error = AIServiceError.invalidURL
            #expect(error.errorDescription == "Invalid server URL")
        }

        @Test("noData errorDescription")
        func noDataDescription() {
            let error = AIServiceError.noData
            #expect(error.errorDescription == "No data received from server")
        }

        @Test("networkError errorDescription contains underlying error localizedDescription")
        func networkErrorDescription() {
            let underlying = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "connection refused"])
            let error = AIServiceError.networkError(underlying)
            let description = error.errorDescription ?? ""
            #expect(description.hasPrefix("Network error: "))
            #expect(description.contains("connection refused"))
        }

        @Test("serverError errorDescription contains status code and message")
        func serverErrorDescription() {
            let error = AIServiceError.serverError(statusCode: 503, message: "Service Unavailable")
            #expect(error.errorDescription == "Server error (503): Service Unavailable")
        }

        @Test("decodingError errorDescription contains underlying error localizedDescription")
        func decodingErrorDescription() {
            let underlying = NSError(domain: "DecodingDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing key"])
            let error = AIServiceError.decodingError(underlying)
            let description = error.errorDescription ?? ""
            #expect(description.hasPrefix("Failed to decode response: "))
            #expect(description.contains("missing key"))
        }
    }

    // MARK: - VectorStoreError

    @Suite("VectorStoreError")
    struct VectorStoreErrorTests {

        @Test("invalidEmbedding errorDescription")
        func invalidEmbeddingDescription() {
            let error = VectorStoreError.invalidEmbedding
            #expect(error.errorDescription == "Invalid embedding data")
        }

        @Test("chunkNotFound errorDescription")
        func chunkNotFoundDescription() {
            let error = VectorStoreError.chunkNotFound
            #expect(error.errorDescription == "Chunk not found")
        }

        @Test("databaseError errorDescription contains message")
        func databaseErrorDescription() {
            let error = VectorStoreError.databaseError("table does not exist")
            #expect(error.errorDescription == "Database error: table does not exist")
        }

        @Test("databaseError with empty message")
        func databaseErrorEmptyMessage() {
            let error = VectorStoreError.databaseError("")
            #expect(error.errorDescription == "Database error: ")
        }
    }

    // MARK: - EmbeddingError

    @Suite("EmbeddingError")
    struct EmbeddingErrorTests {

        @Test("embeddingNotAvailable errorDescription")
        func embeddingNotAvailableDescription() {
            let error = EmbeddingError.embeddingNotAvailable
            #expect(error.errorDescription == "Embedding service is not available")
        }

        @Test("emptyInput errorDescription")
        func emptyInputDescription() {
            let error = EmbeddingError.emptyInput
            #expect(error.errorDescription == "Cannot generate embedding for empty text")
        }

        @Test("embeddingFailed errorDescription contains reason")
        func embeddingFailedDescription() {
            let error = EmbeddingError.embeddingFailed("model not loaded")
            #expect(error.errorDescription == "Failed to generate embedding: model not loaded")
        }

        @Test("networkError errorDescription contains underlying error localizedDescription")
        func networkErrorDescription() {
            let underlying = NSError(domain: "Net", code: 0, userInfo: [NSLocalizedDescriptionKey: "timeout"])
            let error = EmbeddingError.networkError(underlying)
            let description = error.errorDescription ?? ""
            #expect(description.hasPrefix("Network error during embedding: "))
            #expect(description.contains("timeout"))
        }

        @Test("embeddingFailed with empty reason")
        func embeddingFailedEmptyReason() {
            let error = EmbeddingError.embeddingFailed("")
            #expect(error.errorDescription == "Failed to generate embedding: ")
        }
    }
}
