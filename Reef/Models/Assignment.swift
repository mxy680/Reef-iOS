//
//  Assignment.swift
//  Reef
//

import Foundation
import SwiftData

@Model
class Assignment {
    var id: UUID = UUID()
    var name: String              // User-editable display name
    var fileName: String          // Original file name with extension
    var fileExtension: String     // Extension for type detection
    var dateAdded: Date = Date()
    var lastOpenedAt: Date?       // Track when document was last opened
    var thumbnailData: Data?      // JPEG data of PDF first page thumbnail
    var course: Course?           // Relationship to parent course
    var extractedText: String?    // Full text content from PDF for search
    var isTextExtracted: Bool = false // Track if extraction was attempted
    var extractionStatusRaw: String = ExtractionStatus.pending.rawValue
    var extractionMethodRaw: String?
    var ocrConfidence: Double?
    var isVectorIndexed: Bool = false

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

    init(name: String, fileName: String, fileExtension: String, course: Course? = nil) {
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.course = course
    }
}
