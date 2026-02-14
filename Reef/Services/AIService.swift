//
//  AIService.swift
//  Reef
//
//  Networking service for AI endpoints on Reef-Server.
//

import Foundation

// MARK: - Embed Models

struct AIEmbedRequest: Codable {
    let texts: [String]
    let normalize: Bool
}

struct AIEmbedResponse: Codable {
    let embeddings: [[Float]]
    let model: String
    let dimensions: Int
    let count: Int
    let mode: String
}

// MARK: - Error Types

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}

// MARK: - AIService

/// Service for communicating with the Reef-Server AI endpoints
@MainActor
class AIService {
    static let shared = AIService()

    #if DEBUG
    private let baseURL = "http://172.20.87.11:8000"
    #else
    private let baseURL = "https://api.studyreef.com"
    #endif
    private let session: URLSession


    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Embeddings

    /// Generate text embeddings using the server's MiniLM model
    /// - Parameters:
    ///   - texts: Array of texts to embed
    ///   - normalize: Whether to L2-normalize the embeddings (default true)
    ///   - useMock: Whether to use mock mode for testing
    /// - Returns: Array of 384-dimensional embedding vectors
    func embed(
        texts: [String],
        normalize: Bool = true,
        useMock: Bool = false
    ) async throws -> [[Float]] {
        let request = AIEmbedRequest(
            texts: texts,
            normalize: normalize
        )

        var urlString = baseURL + "/ai/embed"
        if useMock {
            urlString += "?mode=mock"
        }

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message: String
            if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorDict["detail"] {
                message = detail
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let embedResponse = try JSONDecoder().decode(AIEmbedResponse.self, from: data)
        return embedResponse.embeddings
    }

    // MARK: - Stroke WebSocket

    private var strokeSocket: URLSessionWebSocketTask?
    private var strokeReconnectAttempts: Int = 0
    private static let maxStrokeReconnectAttempts = 5

    /// Connects to the stroke logging WebSocket endpoint.
    func connectStrokeSocket(sessionId: String? = nil) {
        guard strokeSocket == nil else {
            // Already connected — just send hello if we have a new session ID
            if let sid = sessionId {
                sendHello(sessionId: sid)
            }
            return
        }
        let userId = KeychainService.get(.userIdentifier) ?? ""
        var wsPath = "/ws/strokes"
        if let sid = sessionId {
            wsPath += "?session_id=\(sid)&user_id=\(userId)"
        } else if !userId.isEmpty {
            wsPath += "?user_id=\(userId)"
        }
        let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://").replacingOccurrences(of: "http://", with: "ws://") + wsPath
        guard let url = URL(string: wsURL) else { return }
        let task = session.webSocketTask(with: url)
        strokeSocket = task
        task.resume()
        strokeReconnectAttempts = 0
        listenForStrokeAcks()

    }

    private func sendHello(sessionId: String) {
        guard let socket = strokeSocket else { return }
        let payload: [String: Any] = ["type": "hello", "session_id": sessionId]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { _ in }
    }

    /// Disconnects the stroke WebSocket.
    func disconnectStrokeSocket() {
        strokeSocket?.cancel(with: .normalClosure, reason: nil)
        strokeSocket = nil
    }

    /// Sends stroke point data for a page to the server for logging.
    func sendStrokes(sessionId: String, page: Int, strokes: [[[String: Double]]], eventType: String = "draw", deletedCount: Int = 0) {
        if strokeSocket == nil {
            connectStrokeSocket()
        }
        guard let socket = strokeSocket else { return }

        let userId = KeychainService.get(.userIdentifier) ?? ""
        var payload: [String: Any] = [
            "type": "strokes",
            "event_type": eventType,
            "session_id": sessionId,
            "user_id": userId,
            "page": page,
            "strokes": strokes.map { points in
                ["points": points]
            }
        ]
        if deletedCount > 0 {
            payload["deleted_count"] = deletedCount
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }

        socket.send(.string(text)) { [weak self] error in
            if error != nil {
                DispatchQueue.main.async {
                    self?.strokeSocket?.cancel(with: .abnormalClosure, reason: nil)
                    self?.strokeSocket = nil
                }
            }
        }
    }

    /// Sends a clear command for a session+page, deleting those logs from the DB.
    func sendClear(sessionId: String, page: Int) {
        guard let socket = strokeSocket else { return }

        let payload: [String: Any] = [
            "type": "clear",
            "session_id": sessionId,
            "page": page
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }

        socket.send(.string(text)) { [weak self] error in
            if error != nil {
                DispatchQueue.main.async {
                    self?.strokeSocket?.cancel(with: .abnormalClosure, reason: nil)
                    self?.strokeSocket = nil
                }
            }
        }
    }

    /// Receive loop for ack messages (keeps connection alive).
    private func listenForStrokeAcks() {
        guard let socket = strokeSocket else { return }
        socket.receive { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.listenForStrokeAcks()
                }
            case .failure:
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.strokeSocket = nil
                    self.strokeReconnectAttempts += 1
                    if self.strokeReconnectAttempts <= Self.maxStrokeReconnectAttempts {
                        let delay = min(pow(2.0, Double(self.strokeReconnectAttempts)), 30.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.connectStrokeSocket()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Voice WebSocket

    private var voiceSocket: URLSessionWebSocketTask?

    /// Connect to the voice transcription WebSocket.
    func connectVoiceSocket() {
        guard voiceSocket == nil else { return }
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
            + "/ws/voice"
        guard let url = URL(string: wsURL) else { return }
        let task = session.webSocketTask(with: url)
        voiceSocket = task
        task.resume()
    }

    /// Disconnect the voice WebSocket.
    func disconnectVoiceSocket() {
        voiceSocket?.cancel(with: .normalClosure, reason: nil)
        voiceSocket = nil
    }

    /// Send recorded audio data for transcription.
    /// - Parameters:
    ///   - audioData: WAV audio bytes
    ///   - sessionId: Current document session ID
    ///   - page: Current page number
    func sendVoiceMessage(audioData: Data, sessionId: String, page: Int) {
        if voiceSocket == nil {
            connectVoiceSocket()
        }
        guard let socket = voiceSocket else { return }

        let userId = KeychainService.get(.userIdentifier) ?? ""

        // 1. Send voice_start
        let startPayload: [String: Any] = [
            "type": "voice_start",
            "session_id": sessionId,
            "user_id": userId,
            "page": page
        ]
        guard let startData = try? JSONSerialization.data(withJSONObject: startPayload),
              let startText = String(data: startData, encoding: .utf8) else { return }

        socket.send(.string(startText)) { [weak self] error in
            if let error = error {
                print("[VoiceWS] Failed to send voice_start: \(error)")
                return
            }

            // 2. Send binary audio data
            socket.send(.data(audioData)) { error in
                if let error = error {
                    print("[VoiceWS] Failed to send audio data: \(error)")
                    return
                }

                // 3. Send voice_end
                let endPayload = ["type": "voice_end"]
                guard let endData = try? JSONSerialization.data(withJSONObject: endPayload),
                      let endText = String(data: endData, encoding: .utf8) else { return }

                socket.send(.string(endText)) { error in
                    if let error = error {
                        print("[VoiceWS] Failed to send voice_end: \(error)")
                        return
                    }

                    // 4. Listen for ack with transcription
                    socket.receive { result in
                        switch result {
                        case .success(let message):
                            if case .string(let text) = message,
                               let data = text.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let transcription = json["transcription"] as? String {
                                print("[VoiceWS] Transcription: \(transcription)")
                            }
                        case .failure(let error):
                            print("[VoiceWS] Failed to receive ack: \(error)")
                            DispatchQueue.main.async {
                                self?.voiceSocket = nil
                            }
                        }
                    }
                }
            }
        }
    }

}
