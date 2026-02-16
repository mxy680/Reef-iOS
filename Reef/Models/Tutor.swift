//
//  Tutor.swift
//  Reef
//
//  AI tutor persona models and starter catalog.
//

import SwiftUI

// MARK: - Preset Mode

struct TutorPresetMode: Identifiable, Equatable {
    let id: String
    let name: String
    let patience: Double
    let hintFrequency: Double
    let explanationDepth: Double
}

// MARK: - Tutor

struct Tutor: Identifiable, Equatable {
    let id: String
    let name: String
    let specialty: String
    let tagline: String
    let backstory: String
    let accentColor: Color
    let avatarSymbol: String
    let presetModes: [TutorPresetMode]
}

// MARK: - Catalog

enum TutorCatalog {
    static let allTutors: [Tutor] = [
        Tutor(
            id: "professor-wave",
            name: "Professor Wave",
            specialty: "Math & Physics",
            tagline: "Patient explanations with real-world analogies",
            backstory: "Professor Wave spent years teaching at a seaside university where every lesson connected to the world around them. Whether it's the physics of ocean waves or the geometry of a lighthouse beam, they make abstract concepts tangible and approachable.",
            accentColor: .deepTeal,
            avatarSymbol: "function",
            presetModes: defaultPresets
        ),
        Tutor(
            id: "dr-sage",
            name: "Dr. Sage",
            specialty: "Biology & Chemistry",
            tagline: "Guides you with questions, not answers",
            backstory: "Dr. Sage believes the best way to learn is by discovering answers yourself. Armed with the Socratic method, they ask the right questions at the right time to lead you to breakthroughs — never giving away the solution directly.",
            accentColor: Color(hex: "6B8E6B"),
            avatarSymbol: "leaf.fill",
            presetModes: defaultPresets
        ),
        Tutor(
            id: "coach-rex",
            name: "Coach Rex",
            specialty: "Study Skills",
            tagline: "Motivational, structured, and goal-oriented",
            backstory: "Coach Rex knows that success is built on habits. They combine motivational energy with concrete study strategies — time-boxing, spaced repetition, and active recall — to help you study smarter, not harder.",
            accentColor: .deepCoral,
            avatarSymbol: "figure.run",
            presetModes: defaultPresets
        ),
        Tutor(
            id: "luna",
            name: "Luna",
            specialty: "Literature & History",
            tagline: "Storytelling-based explanations that stick",
            backstory: "Luna weaves every lesson into a story. Historical events become epic narratives, literary themes turn into character journeys, and complex timelines unfold like chapters of a novel. Learning with Luna means you'll never forget the plot.",
            accentColor: Color(hex: "9B7DB8"),
            avatarSymbol: "book.fill",
            presetModes: defaultPresets
        ),
        Tutor(
            id: "byte",
            name: "Byte",
            specialty: "Computer Science",
            tagline: "Concise, logical, and hands-off",
            backstory: "Byte speaks in clean, efficient language — like well-written code. They give you just enough to unblock yourself, prefer pseudocode over paragraphs, and trust you to figure things out with minimal hand-holding.",
            accentColor: Color(hex: "5A7FA5"),
            avatarSymbol: "terminal.fill",
            presetModes: defaultPresets
        ),
    ]

    private static let defaultPresets: [TutorPresetMode] = [
        TutorPresetMode(id: "encouraging", name: "Encouraging", patience: 0.8, hintFrequency: 0.7, explanationDepth: 0.7),
        TutorPresetMode(id: "strict", name: "Strict", patience: 0.3, hintFrequency: 0.2, explanationDepth: 0.4),
        TutorPresetMode(id: "socratic", name: "Socratic", patience: 0.7, hintFrequency: 0.3, explanationDepth: 0.5),
        TutorPresetMode(id: "hands-off", name: "Hands-off", patience: 0.5, hintFrequency: 0.1, explanationDepth: 0.3),
    ]

    static func tutor(for id: String) -> Tutor? {
        allTutors.first { $0.id == id }
    }
}
