//
//  PreferencesManager.swift
//  Reef
//
//  Manages user preferences with @AppStorage persistence.
//

import SwiftUI

// MARK: - Enums

enum ReasoningModel: String, CaseIterable, Identifiable {
    case gpt4o = "GPT-4o"
    case claudeSonnet = "Claude Sonnet"
    case geminiPro = "Gemini Pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o (Recommended)"
        case .claudeSonnet: return "Claude Sonnet"
        case .geminiPro: return "Gemini Pro"
        }
    }
}

enum FeedbackDetailLevel: String, CaseIterable, Identifiable {
    case concise = "Concise"
    case balanced = "Balanced"
    case detailed = "Detailed"

    var id: String { rawValue }
}

enum RecognitionLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case chinese = "Chinese"
    case japanese = "Japanese"

    var id: String { rawValue }
}

enum DifficultyLevel: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

enum TimeLimitOption: String, CaseIterable, Identifiable {
    case none = "No Limit"
    case minutes15 = "15 minutes"
    case minutes30 = "30 minutes"
    case minutes45 = "45 minutes"
    case minutes60 = "60 minutes"
    case minutes90 = "90 minutes"
    case minutes120 = "120 minutes"

    var id: String { rawValue }

    var minutes: Int? {
        switch self {
        case .none: return nil
        case .minutes15: return 15
        case .minutes30: return 30
        case .minutes45: return 45
        case .minutes60: return 60
        case .minutes90: return 90
        case .minutes120: return 120
        }
    }
}

// MARK: - PreferencesManager

@MainActor
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private init() {}

    // MARK: - AI Settings

    @AppStorage("reasoningModel") var reasoningModel: String = ReasoningModel.gpt4o.rawValue
    @AppStorage("pauseDetectionSensitivity") var pauseDetectionSensitivity: Double = 0.5
    @AppStorage("autoFeedbackEnabled") var autoFeedbackEnabled: Bool = true
    @AppStorage("feedbackDetailLevel") var feedbackDetailLevel: String = FeedbackDetailLevel.balanced.rawValue
    @AppStorage("recognitionLanguage") var recognitionLanguage: String = RecognitionLanguage.english.rawValue

    // MARK: - Quiz Defaults

    @AppStorage("quizDefaultDifficulty") var quizDefaultDifficulty: String = DifficultyLevel.medium.rawValue
    @AppStorage("quizDefaultQuestionCount") var quizDefaultQuestionCount: Int = 10
    @AppStorage("quizPreferredQuestionTypes") var quizPreferredQuestionTypesData: Data = {
        let defaultTypes: Set<String> = [QuestionType.multipleChoice.rawValue]
        return (try? JSONEncoder().encode(defaultTypes)) ?? Data()
    }()
    @AppStorage("quizDefaultTimeLimit") var quizDefaultTimeLimit: String = TimeLimitOption.minutes30.rawValue

    // MARK: - Exam Defaults

    @AppStorage("examDefaultDifficulty") var examDefaultDifficulty: String = DifficultyLevel.medium.rawValue
    @AppStorage("examDefaultPassingScore") var examDefaultPassingScore: Double = 70
    @AppStorage("examDefaultTimeLimit") var examDefaultTimeLimit: String = TimeLimitOption.minutes60.rawValue
    @AppStorage("examShowTimer") var examShowTimer: Bool = true

    // MARK: - Topic Weighting

    @AppStorage("focusOnWeakAreas") var focusOnWeakAreas: Bool = true
    @AppStorage("weakAreaWeight") var weakAreaWeight: Double = 0.7

    // MARK: - Privacy Settings

    @AppStorage("indexDocumentsForAI") var indexDocumentsForAI: Bool = true
    @AppStorage("shareUsageAnalytics") var shareUsageAnalytics: Bool = true
    @AppStorage("shareCrashReports") var shareCrashReports: Bool = true

    // MARK: - Quiz Question Types Helpers

    var quizPreferredQuestionTypes: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: quizPreferredQuestionTypesData)) ?? [QuestionType.multipleChoice.rawValue]
        }
        set {
            quizPreferredQuestionTypesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func isQuestionTypeSelected(_ type: QuestionType) -> Bool {
        quizPreferredQuestionTypes.contains(type.rawValue)
    }

    func toggleQuestionType(_ type: QuestionType) {
        var types = quizPreferredQuestionTypes
        if types.contains(type.rawValue) {
            // Don't remove if it's the last one
            if types.count > 1 {
                types.remove(type.rawValue)
            }
        } else {
            types.insert(type.rawValue)
        }
        quizPreferredQuestionTypes = types
    }

    // MARK: - Convenience Getters

    var selectedReasoningModel: ReasoningModel {
        ReasoningModel(rawValue: reasoningModel) ?? .gpt4o
    }

    var selectedFeedbackDetailLevel: FeedbackDetailLevel {
        FeedbackDetailLevel(rawValue: feedbackDetailLevel) ?? .balanced
    }

    var selectedRecognitionLanguage: RecognitionLanguage {
        RecognitionLanguage(rawValue: recognitionLanguage) ?? .english
    }

    var selectedQuizDifficulty: DifficultyLevel {
        DifficultyLevel(rawValue: quizDefaultDifficulty) ?? .medium
    }

    var selectedExamDifficulty: DifficultyLevel {
        DifficultyLevel(rawValue: examDefaultDifficulty) ?? .medium
    }

    var selectedQuizTimeLimit: TimeLimitOption {
        TimeLimitOption(rawValue: quizDefaultTimeLimit) ?? .minutes30
    }

    var selectedExamTimeLimit: TimeLimitOption {
        TimeLimitOption(rawValue: examDefaultTimeLimit) ?? .minutes60
    }
}
