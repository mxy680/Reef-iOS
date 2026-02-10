//
//  TutoringWebSocketService.swift
//  Reef
//
//  WebSocket client for the real-time AI tutoring pipeline.
//  Handles session lifecycle, screenshot streaming, pause/help signals,
//  and receiving transcription, feedback, and audio responses.
//

import Foundation

@MainActor
final class TutoringWebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let baseURL = "wss://api.studyreef.com"

    // MARK: - Callbacks

    /// Called when a transcription arrives: (deltaLatex, fullLatex, batchIndex)
    var onTranscriptionComplete: ((String, Int) -> Void)?

    /// Called when tutor audio arrives: (audioData, text, status, confidence)
    var onTutorAudio: ((Data, String, String, Double) -> Void)?

    /// Called when text-only feedback arrives: (text, status, confidence)
    var onTutorFeedback: ((String, String, Double) -> Void)?

    // MARK: - Connection

    func connect() {
        disconnect()

        guard let url = URL(string: "\(baseURL)/ws/tutor") else {
            print("[Tutor WS] Invalid URL")
            return
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        print("[Tutor WS] Connecting to \(url)")
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Session Lifecycle

    func startSession(
        problemId: String,
        questionNumber: Int,
        problemText: String,
        problemParts: [[String: String]],
        courseName: String
    ) {
        ensureConnected()

        let payload: [String: Any] = [
            "type": "session_start",
            "problem_id": problemId,
            "question_number": questionNumber,
            "problem_text": problemText,
            "problem_parts": problemParts,
            "course_name": courseName,
        ]
        sendJSON(payload)
        print("[Tutor WS] Session started: Q\(questionNumber)")
    }

    func endSession() {
        let payload: [String: Any] = ["type": "session_end"]
        sendJSON(payload)
        print("[Tutor WS] Session ended")
    }

    // MARK: - Send Messages

    func sendScreenshot(
        imageData: Data,
        batchIndex: Int,
        questionNumber: Int?,
        subquestion: String?,
        hasErasures: Bool = false
    ) {
        ensureConnected()

        let payload: [String: Any] = [
            "type": "screenshot",
            "image": imageData.base64EncodedString(),
            "batch_index": batchIndex,
            "question_number": questionNumber as Any,
            "subquestion": subquestion as Any,
            "has_erasures": hasErasures,
        ]
        sendJSON(payload)
    }

    func sendPause(duration: TimeInterval, strokeCount: Int, questionNumber: Int?, subquestion: String?) {
        let payload: [String: Any] = [
            "type": "pause",
            "duration": duration,
            "stroke_count": strokeCount,
            "question_number": questionNumber as Any,
            "subquestion": subquestion as Any,
        ]
        sendJSON(payload)
    }

    func sendHelp(questionNumber: Int?, subquestion: String?) {
        let payload: [String: Any] = [
            "type": "help",
            "question_number": questionNumber as Any,
            "subquestion": subquestion as Any,
        ]
        sendJSON(payload)
        print("[Tutor WS] Help requested")
    }

    // MARK: - Private Helpers

    private func ensureConnected() {
        if webSocketTask == nil {
            connect()
        }
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let task = webSocketTask else { return }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[Tutor WS] Failed to encode message")
            return
        }

        task.send(.string(jsonString)) { error in
            if let error {
                print("[Tutor WS] Send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Receive

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessages()
                case .failure(let error):
                    print("[Tutor WS] Receive error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "transcription":
            let batchIndex = json["batch_index"] as? Int ?? 0
            if let deltaLatex = json["delta_latex"] as? String {
                onTranscriptionComplete?(deltaLatex, batchIndex)
            }

        case "tutor_audio":
            if let audioB64 = json["audio_b64"] as? String,
               let audioData = Data(base64Encoded: audioB64),
               let feedbackText = json["text"] as? String,
               let status = json["status"] as? String {
                let confidence = json["confidence"] as? Double ?? 0.0
                onTutorAudio?(audioData, feedbackText, status, confidence)
            }

        case "tutor_feedback":
            if let feedbackText = json["text"] as? String,
               let status = json["status"] as? String {
                let confidence = json["confidence"] as? Double ?? 0.0
                onTutorFeedback?(feedbackText, status, confidence)
            }

        case "error":
            let batchIndex = json["batch_index"] as? Int
            let errorMsg = json["message"] as? String ?? "Unknown error"
            print("[Tutor WS] Server error\(batchIndex.map { " (batch \($0))" } ?? ""): \(errorMsg)")

        default:
            break
        }
    }
}
