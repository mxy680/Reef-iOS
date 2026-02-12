//
//  Quiz.swift
//  Reef
//
//  SwiftData model for generated quizzes.
//

import Foundation
import SwiftData

// MARK: - Quiz Question Item

struct QuizQuestionItem: Codable, Identifiable {
    var id: UUID = UUID()
    let questionNumber: Int
    let pdfFileName: String
    let topic: String?
}

// MARK: - Quiz Model

@Model
class Quiz {
    var id: UUID = UUID()
    var course: Course?
    var topic: String
    var difficultyRaw: String
    var numberOfQuestions: Int
    var dateCreated: Date = Date()
    var sourceNoteIds: [UUID]
    var usedGeneralKnowledge: Bool = false
    var questionsData: Data?

    var questions: [QuizQuestionItem] {
        get {
            guard let data = questionsData else { return [] }
            return (try? JSONDecoder().decode([QuizQuestionItem].self, from: data)) ?? []
        }
        set {
            questionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var difficulty: QuizDifficulty {
        QuizDifficulty(rawValue: difficultyRaw) ?? .medium
    }

    init(
        topic: String,
        difficulty: QuizDifficulty,
        numberOfQuestions: Int,
        sourceNoteIds: [UUID],
        usedGeneralKnowledge: Bool = false,
        course: Course? = nil
    ) {
        self.topic = topic
        self.difficultyRaw = difficulty.rawValue
        self.numberOfQuestions = numberOfQuestions
        self.sourceNoteIds = sourceNoteIds
        self.usedGeneralKnowledge = usedGeneralKnowledge
        self.course = course
    }
}
