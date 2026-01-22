//
//  Material.swift
//  Reef
//

import Foundation
import SwiftData

@Model
class Material {
    var id: UUID = UUID()
    var name: String              // User-editable display name
    var fileName: String          // Original file name with extension
    var fileExtension: String     // Extension for type detection
    var dateAdded: Date = Date()
    var course: Course?           // Relationship to parent course
    var extractedText: String?    // Full text content from PDF for search
    var isTextExtracted: Bool = false // Track if extraction was attempted

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
