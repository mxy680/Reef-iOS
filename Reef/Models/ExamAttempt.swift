//
//  ExamAttempt.swift
//  Reef
//

import Foundation
import SwiftData

// MARK: - Question Type

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case multipleChoice
    case fillInBlank
    case openEnded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .multipleChoice: return "Multiple Choice"
        case .fillInBlank: return "Fill-in-the-blank"
        case .openEnded: return "Open-ended"
        }
    }
}

// MARK: - Exam Question

@Model
class ExamQuestion {
    var id: UUID
    var questionText: String
    var questionType: QuestionType
    var options: [String]?
    var correctAnswer: String
    var studentAnswer: String?
    var isCorrect: Bool?
    var topic: String

    init(
        questionText: String,
        questionType: QuestionType,
        options: [String]? = nil,
        correctAnswer: String,
        topic: String
    ) {
        self.id = UUID()
        self.questionText = questionText
        self.questionType = questionType
        self.options = options
        self.correctAnswer = correctAnswer
        self.topic = topic
    }
}

// MARK: - Exam Attempt

@Model
class ExamAttempt {
    var id: UUID
    var courseName: String
    var dateTaken: Date
    var timeLimit: Int // minutes
    var passingScore: Int // percentage
    var scoreAchieved: Int? // percentage, nil if not completed
    var passed: Bool?
    var speciesUnlocked: String?
    @Relationship(deleteRule: .cascade)
    var questions: [ExamQuestion]
    var weakAreas: [String]
    var isCompleted: Bool

    init(
        courseName: String,
        timeLimit: Int,
        passingScore: Int,
        questions: [ExamQuestion] = []
    ) {
        self.id = UUID()
        self.courseName = courseName
        self.dateTaken = Date()
        self.timeLimit = timeLimit
        self.passingScore = passingScore
        self.questions = questions
        self.weakAreas = []
        self.isCompleted = false
    }
}
