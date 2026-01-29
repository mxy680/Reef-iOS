//
//  Note.swift
//  Reef
//

import Foundation
import SwiftData

@Model
class Note: Hashable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: UUID = UUID()
    var name: String              // User-editable display name
    var fileName: String          // Original file name with extension
    var fileExtension: String     // Extension for type detection
    var dateAdded: Date = Date()
    var lastOpenedAt: Date?       // Track when document was last opened
    var course: Course?           // Relationship to parent course
    var extractedText: String?    // Full text content from PDF for search
    var isTextExtracted: Bool = false // Track if extraction was attempted
    var extractionStatusRaw: String = ExtractionStatus.pending.rawValue
    var extractionMethodRaw: String?
    var ocrConfidence: Double?
    var isVectorIndexed: Bool = false
    var isAssignment: Bool = false

    var extractionStatus: ExtractionStatus {
        get { ExtractionStatus(rawValue: extractionStatusRaw) ?? .pending }
        set { extractionStatusRaw = newValue.rawValue }
    }

    var extractionMethod: ExtractionMethod? {
        get { extractionMethodRaw.flatMap { ExtractionMethod(rawValue: $0) } }
        set { extractionMethodRaw = newValue?.rawValue }
    }

    var fileType: FileType {
        switch fileExtension.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "heic": return .image
        default: return .document
        }
    }

    var fileTypeIcon: String {
        switch fileType {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .document: return "doc.text.fill"
        }
    }

    enum FileType: String, Codable {
        case pdf, image, document
    }

    /// True if any background processing for AI features is still in progress
    var isProcessingForAI: Bool {
        extractionStatus == .extracting ||
        (extractionStatus == .completed && !isVectorIndexed)
    }

    /// True when all AI processing is complete and AI features are ready to use
    var isAIReady: Bool {
        extractionStatus == .completed &&
        isVectorIndexed
    }

    init(name: String, fileName: String, fileExtension: String, course: Course? = nil) {
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.course = course
    }
}
