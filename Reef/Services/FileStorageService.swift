//
//  FileStorageService.swift
//  Reef
//

import Foundation

class FileStorageService {
    static let shared = FileStorageService()

    private let fileManager = FileManager.default
    private let documentsDirectoryName = "Documents"

    private init() {
        createDocumentsDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private var appDocumentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var storedDocumentsDirectory: URL {
        appDocumentsDirectory.appendingPathComponent(documentsDirectoryName)
    }

    private func createDocumentsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storedDocumentsDirectory.path) {
            try? fileManager.createDirectory(at: storedDocumentsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - File Operations

    /// Copies a file from source URL to the documents directory
    /// - Parameters:
    ///   - sourceURL: The URL of the file to copy
    ///   - documentID: The UUID of the document (used as filename)
    ///   - fileExtension: The file extension to use
    /// - Returns: The URL of the copied file
    func copyFile(from sourceURL: URL, documentID: UUID, fileExtension: String) throws -> URL {
        let destinationURL = storedDocumentsDirectory
            .appendingPathComponent(documentID.uuidString)
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

    /// Gets the URL for a stored document
    func getFileURL(for documentID: UUID, fileExtension: String) -> URL {
        storedDocumentsDirectory
            .appendingPathComponent(documentID.uuidString)
            .appendingPathExtension(fileExtension)
    }

    /// Deletes a document's file from storage
    func deleteFile(documentID: UUID, fileExtension: String) throws {
        let fileURL = getFileURL(for: documentID, fileExtension: fileExtension)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Checks if a file exists for the given document
    func fileExists(documentID: UUID, fileExtension: String) -> Bool {
        let fileURL = getFileURL(for: documentID, fileExtension: fileExtension)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}
