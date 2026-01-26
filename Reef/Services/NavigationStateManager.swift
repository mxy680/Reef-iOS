//
//  NavigationStateManager.swift
//  Reef
//

import SwiftUI

/// Persists navigation state across app restarts using AppStorage (UserDefaults).
/// Stores sidebar selection, course/section, note selection, and canvas view state.
@MainActor
class NavigationStateManager: ObservableObject {
    static let shared = NavigationStateManager()

    // MARK: - Persisted State

    @AppStorage("nav_sidebarItem") var selectedSidebarItemRaw: String?
    @AppStorage("nav_courseID") var selectedCourseID: String?
    @AppStorage("nav_section") var selectedSectionRaw: String?
    @AppStorage("nav_noteID") var selectedNoteID: String?
    @AppStorage("nav_isViewingCanvas") var isViewingCanvas: Bool = false

    private init() {}

    // MARK: - Computed Properties

    var selectedSidebarItem: SidebarItem? {
        get {
            guard let raw = selectedSidebarItemRaw else { return nil }
            return SidebarItem(rawValue: raw)
        }
        set {
            selectedSidebarItemRaw = newValue?.rawValue
        }
    }

    var selectedSection: CourseSection? {
        get {
            guard let raw = selectedSectionRaw else { return nil }
            return CourseSection(rawValue: raw)
        }
        set {
            selectedSectionRaw = newValue?.rawValue
        }
    }

    // MARK: - Save Methods

    func saveSidebarItem(_ item: SidebarItem?) {
        selectedSidebarItem = item
    }

    func saveCourse(_ course: Course?) {
        selectedCourseID = course?.id.uuidString
    }

    func saveSection(_ section: CourseSection?) {
        selectedSection = section
    }

    func saveNote(_ note: Note?) {
        selectedNoteID = note?.id.uuidString
    }

    func saveCanvasState(_ isViewing: Bool) {
        isViewingCanvas = isViewing
    }

    // MARK: - Restore Methods

    /// Finds a Course from the persisted ID in the given collection.
    func restoreCourse(from courses: [Course]) -> Course? {
        guard let idString = selectedCourseID,
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return courses.first { $0.id == uuid }
    }

    /// Finds a Note from the persisted ID within the given Course.
    func restoreNote(from course: Course?) -> Note? {
        guard let course = course,
              let idString = selectedNoteID,
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return course.notes.first { $0.id == uuid }
    }

    // MARK: - Clear State

    /// Clears all persisted navigation state. Call on sign out.
    func clearState() {
        selectedSidebarItemRaw = nil
        selectedCourseID = nil
        selectedSectionRaw = nil
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
        selectedSectionRaw = nil
        selectedNoteID = nil
        isViewingCanvas = false
    }
}
