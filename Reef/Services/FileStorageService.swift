//
//  FileStorageService.swift
//  Reef
//

import Foundation

class FileStorageService {
    static let shared = FileStorageService()

    private let fileManager = FileManager.default
    private let materialsDirectoryName = "Materials"

    private init() {
        createMaterialsDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var materialsDirectory: URL {
        documentsDirectory.appendingPathComponent(materialsDirectoryName)
    }

    private func createMaterialsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: materialsDirectory.path) {
            try? fileManager.createDirectory(at: materialsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Operations

    /// Copies a file from source URL to the materials directory
    /// - Parameters:
    ///   - sourceURL: The URL of the file to copy
    ///   - materialID: The UUID of the material (used as filename)
    ///   - fileExtension: The file extension to use
    /// - Returns: The URL of the copied file
    func copyFile(from sourceURL: URL, materialID: UUID, fileExtension: String) throws -> URL {
        let destinationURL = materialsDirectory
            .appendingPathComponent(materialID.uuidString)
            .appendingPathExtension(fileExtension)

        // Start accessing security-scoped resource
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    /// Gets the URL for a stored material
    func getFileURL(for materialID: UUID, fileExtension: String) -> URL {
        materialsDirectory
            .appendingPathComponent(materialID.uuidString)
            .appendingPathExtension(fileExtension)
    }

    /// Deletes a material's file from storage
    func deleteFile(materialID: UUID, fileExtension: String) throws {
        let fileURL = getFileURL(for: materialID, fileExtension: fileExtension)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Checks if a file exists for the given material
    func fileExists(materialID: UUID, fileExtension: String) -> Bool {
        let fileURL = getFileURL(for: materialID, fileExtension: fileExtension)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
