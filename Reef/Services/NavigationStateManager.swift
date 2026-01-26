//
//  NavigationStateManager.swift
//  Reef
//

import SwiftUI

/// Persists navigation state across app restarts using AppStorage (UserDefaults).
/// Stores sidebar selection, course/section, note selection, and canvas view state.
/// Uses raw strings to avoid coupling to model types defined elsewhere.
@MainActor
class NavigationStateManager: ObservableObject {
    static let shared = NavigationStateManager()

    // MARK: - Persisted State (raw strings for decoupling)

    @AppStorage("nav_sidebarItem") var selectedSidebarItemRaw: String?
    @AppStorage("nav_courseID") var selectedCourseID: String?
    @AppStorage("nav_courseSubPage") var selectedCourseSubPage: String? // "notes", "quizzes", "exams"
    @AppStorage("nav_noteID") var selectedNoteID: String?
    @AppStorage("nav_isViewingCanvas") var isViewingCanvas: Bool = false

    private init() {}

    // MARK: - Clear State

    /// Clears all persisted navigation state. Call on sign out.
    func clearState() {
        selectedSidebarItemRaw = nil
        selectedCourseID = nil
        selectedCourseSubPage = nil
        selectedNoteID = nil
        isViewingCanvas = false
    }

    /// Clears only the note-related state (when note is deleted or not found).
    func clearNoteState() {
        selectedNoteID = nil
        isViewingCanvas = false
    }

    /// Clears course and downstream state (when course is deleted or not found).
    func clearCourseState() {
        selectedCourseID = nil
        selectedCourseSubPage = nil
        selectedNoteID = nil
        isViewingCanvas = false
    }
}
