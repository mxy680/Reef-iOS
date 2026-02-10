//
//  TutoringWebSocketService.swift
//  Reef
//
//  WebSocket client for streaming handwriting screenshots to the server
//  and receiving real-time transcriptions back.
//

import Foundation

@MainActor
final class TutoringWebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let baseURL = "wss://api.studyreef.com"

    /// Called for each streaming text chunk: (text, batchIndex)
    var onTranscriptionDelta: ((String, Int) -> Void)?

    /// Called when full transcription is available: (fullText, batchIndex)
    var onTranscriptionComplete: ((String, Int) -> Void)?

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

    // MARK: - Send

    func sendScreenshot(
        imageData: Data,
        batchIndex: Int,
        questionNumber: Int?,
        subquestion: String?
    ) {
        guard let task = webSocketTask else { return }

        let payload: [String: Any] = [
            "type": "screenshot",
            "image": imageData.base64EncodedString(),
            "batch_index": batchIndex,
            "question_number": questionNumber as Any,
            "subquestion": subquestion as Any,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[Tutor WS] Failed to encode screenshot message")
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
                    self.receiveMessages() // Continue listening
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

        let batchIndex = json["batch_index"] as? Int ?? 0

        switch type {
        case "transcription_delta":
            if let deltaText = json["text"] as? String {
                onTranscriptionDelta?(deltaText, batchIndex)
            }
        case "transcription_complete":
            if let fullText = json["text"] as? String {
                onTranscriptionComplete?(fullText, batchIndex)
            }
        case "error":
            let errorMsg = json["message"] as? String ?? "Unknown error"
            print("[Tutor WS] Server error (batch \(batchIndex)): \(errorMsg)")
        default:
            break
        }
    }
}
