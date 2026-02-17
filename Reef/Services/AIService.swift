//
//  AIService.swift
//  Reef
//
//  Networking service for AI endpoints on Reef-Server.
//

import AVFoundation
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
    private let baseURL = "https://assistant-evaluate-rss-copying.trycloudflare.com"
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

    // MARK: - Stroke REST

    /// The current stroke session ID, reused for voice messages.
    private(set) var currentSessionId: String?

    /// Fire-and-forget JSON POST helper for stroke endpoints.
    private func postJSON(path: String, body: [String: Any]) {
        guard let url = URL(string: baseURL + path) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { _, _, _ in }.resume()
    }

    /// Notify server of session start.
    func connectStrokeSession(sessionId: String, documentName: String? = nil, questionNumber: Int? = nil) {
        currentSessionId = sessionId
        var body: [String: Any] = [
            "session_id": sessionId,
            "user_id": KeychainService.get(.userIdentifier) ?? ""
        ]
        if let dn = documentName { body["document_name"] = dn }
        if let qn = questionNumber { body["question_number"] = qn }
        postJSON(path: "/api/strokes/connect", body: body)
    }

    /// Notify server of session end.
    func disconnectStrokeSession() {
        guard let sid = currentSessionId else { return }
        postJSON(path: "/api/strokes/disconnect", body: ["session_id": sid])
        currentSessionId = nil
    }

    /// Sends stroke point data for a page to the server for logging.
    func sendStrokes(sessionId: String, page: Int, strokes: [[[String: Double]]], eventType: String = "draw", deletedCount: Int = 0) {
        var body: [String: Any] = [
            "session_id": sessionId,
            "user_id": KeychainService.get(.userIdentifier) ?? "",
            "page": page,
            "strokes": strokes.map { ["points": $0] },
            "event_type": eventType
        ]
        if deletedCount > 0 { body["deleted_count"] = deletedCount }
        postJSON(path: "/api/strokes", body: body)
    }

    /// Sends a clear command for a session+page, deleting those logs from the DB.
    func sendClear(sessionId: String, page: Int) {
        postJSON(path: "/api/strokes/clear", body: ["session_id": sessionId, "page": page])
    }

    // MARK: - Reasoning WebSocket

    private var reasoningSocket: URLSessionWebSocketTask?
    private var reasoningSessionId: String?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var currentTTSSampleRate: Double = 24000

    /// Connect to the reasoning WebSocket to receive tutor responses and TTS audio.
    func connectReasoningSocket(sessionId: String) {
        guard reasoningSocket == nil else { return }
        reasoningSessionId = sessionId
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
            + "/ws/reasoning?session_id=\(sessionId)"
        guard let url = URL(string: wsURL) else {
            print("[ReasoningWS] Invalid URL")
            return
        }
        print("[ReasoningWS] Connecting to \(wsURL)")
        let task = session.webSocketTask(with: url)
        reasoningSocket = task
        task.resume()
        listenForReasoningMessages()
    }

    /// Ensure reasoning WebSocket is connected, reconnecting if dropped.
    private func ensureReasoningSocket() {
        guard let sid = reasoningSessionId else { return }
        if let existing = reasoningSocket {
            existing.cancel(with: .normalClosure, reason: nil)
            reasoningSocket = nil
        }
        connectReasoningSocket(sessionId: sid)
    }

    /// Disconnect the reasoning WebSocket.
    func disconnectReasoningSocket() {
        reasoningSocket?.cancel(with: .normalClosure, reason: nil)
        reasoningSocket = nil
        reasoningSessionId = nil
        stopAudioPlayback()
    }

    /// Listen for reasoning messages (text JSON + binary TTS audio).
    private func listenForReasoningMessages() {
        reasoningSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String {
                        if type == "reasoning" {
                            let msg = json["message"] as? String ?? ""
                            print("[ReasoningWS] Reasoning: \(msg.prefix(80))")
                        } else if type == "tts_start" {
                            let sampleRate = json["sample_rate"] as? Double ?? 24000
                            DispatchQueue.main.async {
                                self.startAudioPlayback(sampleRate: sampleRate)
                            }
                        } else if type == "tts_end" {
                            print("[ReasoningWS] TTS stream ended")
                        }
                    }
                case .data(let data):
                    DispatchQueue.main.async {
                        self.playAudioChunk(data)
                    }
                @unknown default:
                    break
                }
                self.listenForReasoningMessages()
            case .failure(let error):
                print("[ReasoningWS] Receive error: \(error)")
                DispatchQueue.main.async {
                    self.reasoningSocket = nil
                }
            }
        }
    }

    // MARK: - TTS Audio Playback

    private func startAudioPlayback(sampleRate: Double) {
        stopAudioPlayback()
        currentTTSSampleRate = sampleRate

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            print("[ReasoningWS] Failed to create audio format")
            return
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
            audioEngine = engine
            audioPlayer = player
            print("[ReasoningWS] Audio playback started")
        } catch {
            print("[ReasoningWS] Failed to start audio: \(error)")
        }
    }

    private func playAudioChunk(_ data: Data) {
        guard let player = audioPlayer, let engine = audioEngine, engine.isRunning else { return }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: currentTTSSampleRate,
            channels: 1,
            interleaved: true
        ) else { return }

        let frameCount = UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        data.withUnsafeBytes { rawBuffer in
            if let src = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData![0], src, data.count)
            }
        }
        player.scheduleBuffer(buffer)
    }

    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioEngine?.stop()
        audioPlayer = nil
        audioEngine = nil
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
        guard let url = URL(string: wsURL) else {
            print("[VoiceWS] Invalid URL")
            return
        }
        print("[VoiceWS] Connecting to \(wsURL)")
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
        print("[VoiceWS] sendVoiceMessage called — \(audioData.count) bytes, session=\(sessionId)")
        if voiceSocket == nil {
            connectVoiceSocket()
        }
        guard let socket = voiceSocket else {
            print("[VoiceWS] voiceSocket is nil after connect attempt")
            return
        }

        let userId = KeychainService.get(.userIdentifier) ?? ""

        // 1. Send voice_start
        let startPayload: [String: Any] = [
            "type": "voice_start",
            "session_id": sessionId,
            "user_id": userId,
            "page": page
        ]
        guard let startData = try? JSONSerialization.data(withJSONObject: startPayload),
              let startText = String(data: startData, encoding: .utf8) else {
            print("[VoiceWS] Failed to serialize voice_start payload")
            return
        }

        // Fire-and-forget sends (same pattern as stroke socket)
        print("[VoiceWS] Sending voice_start...")
        socket.send(.string(startText)) { error in
            if let error = error { print("[VoiceWS] voice_start error: \(error)") }
        }

        // 2. Send binary audio data
        print("[VoiceWS] Sending \(audioData.count) bytes of audio...")
        socket.send(.data(audioData)) { error in
            if let error = error { print("[VoiceWS] audio data error: \(error)") }
        }

        // 3. Send voice_end
        let endText = "{\"type\":\"voice_end\"}"
        print("[VoiceWS] Sending voice_end...")
        socket.send(.string(endText)) { error in
            if let error = error { print("[VoiceWS] voice_end error: \(error)") }
        }

        // 4. Listen for ack
        socket.receive { [weak self] result in
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

    /// Send recorded audio as a voice question for immediate reasoning response.
    func sendVoiceQuestion(audioData: Data, sessionId: String, page: Int) {
        print("[VoiceWS] sendVoiceQuestion called — \(audioData.count) bytes")
        if voiceSocket == nil {
            connectVoiceSocket()
        }
        guard let socket = voiceSocket else {
            print("[VoiceWS] voiceSocket is nil after connect attempt")
            return
        }

        let userId = KeychainService.get(.userIdentifier) ?? ""

        // 1. Send voice_start with mode: "question"
        let startPayload: [String: Any] = [
            "type": "voice_start",
            "session_id": sessionId,
            "user_id": userId,
            "page": page,
            "mode": "question"
        ]
        guard let startData = try? JSONSerialization.data(withJSONObject: startPayload),
              let startText = String(data: startData, encoding: .utf8) else {
            print("[VoiceWS] Failed to serialize voice_start payload")
            return
        }

        socket.send(.string(startText)) { error in
            if let error = error { print("[VoiceWS] voice_start error: \(error)") }
        }

        // 2. Send binary audio data
        print("[VoiceWS] Sending \(audioData.count) bytes of question audio...")
        socket.send(.data(audioData)) { error in
            if let error = error { print("[VoiceWS] audio data error: \(error)") }
        }

        // 3. Send voice_end
        let endText = "{\"type\":\"voice_end\"}"
        socket.send(.string(endText)) { error in
            if let error = error { print("[VoiceWS] voice_end error: \(error)") }
        }

        // 4. Listen for ack + reasoning + TTS stream on this socket
        listenForVoiceResponse(on: socket)
    }

    /// Listen for ack, reasoning text, and TTS audio on the voice WebSocket.
    private func listenForVoiceResponse(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String {
                        if type == "ack" {
                            let transcription = json["transcription"] as? String ?? ""
                            print("[VoiceWS] Question ack: \(transcription.prefix(80))")
                            // Keep listening for reasoning + TTS
                            self.listenForVoiceResponse(on: socket)
                        } else if type == "reasoning" {
                            let msg = json["message"] as? String ?? ""
                            print("[VoiceWS] Reasoning: \(msg.prefix(80))")
                            self.listenForVoiceResponse(on: socket)
                        } else if type == "tts_start" {
                            let sampleRate = json["sample_rate"] as? Double ?? 24000
                            print("[VoiceWS] Audio playback started")
                            DispatchQueue.main.async {
                                self.startAudioPlayback(sampleRate: sampleRate)
                            }
                            self.listenForVoiceResponse(on: socket)
                        } else if type == "tts_end" {
                            print("[VoiceWS] TTS stream ended")
                            // Done — stop listening, voice WS stays open for next question
                        } else {
                            // Unknown type, keep listening
                            self.listenForVoiceResponse(on: socket)
                        }
                    } else {
                        self.listenForVoiceResponse(on: socket)
                    }
                case .data(let data):
                    DispatchQueue.main.async {
                        self.playAudioChunk(data)
                    }
                    self.listenForVoiceResponse(on: socket)
                @unknown default:
                    self.listenForVoiceResponse(on: socket)
                }
            case .failure(let error):
                print("[VoiceWS] Voice response error: \(error)")
                DispatchQueue.main.async {
                    self.voiceSocket = nil
                }
            }
        }
    }

}
