//
//  TutorSelectionManager.swift
//  Reef
//
//  Persists the student's selected tutor and customization settings.
//

import SwiftUI

@MainActor
class TutorSelectionManager: ObservableObject {
    static let shared = TutorSelectionManager()

    @AppStorage("selectedTutorID") var selectedTutorID: String? {
        didSet { objectWillChange.send() }
    }

    @AppStorage("selectedPresetID") var selectedPresetID: String? {
        didSet { objectWillChange.send() }
    }

    @AppStorage("customPatience") var customPatience: Double = 0.5 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("customHintFrequency") var customHintFrequency: Double = 0.5 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("customExplanationDepth") var customExplanationDepth: Double = 0.5 {
        didSet { objectWillChange.send() }
    }

    private init() {}

    var selectedTutor: Tutor? {
        guard let id = selectedTutorID else { return nil }
        return TutorCatalog.tutor(for: id)
    }

    var selectedPreset: TutorPresetMode? {
        guard let presetID = selectedPresetID, let tutor = selectedTutor else { return nil }
        return tutor.presetModes.first { $0.id == presetID }
    }

    func selectTutor(_ tutor: Tutor, preset: TutorPresetMode?) {
        selectedTutorID = tutor.id
        if let preset {
            applyPreset(preset)
        }
    }

    func applyPreset(_ preset: TutorPresetMode) {
        selectedPresetID = preset.id
        customPatience = preset.patience
        customHintFrequency = preset.hintFrequency
        customExplanationDepth = preset.explanationDepth
    }

    func clearPreset() {
        selectedPresetID = nil
    }
}
