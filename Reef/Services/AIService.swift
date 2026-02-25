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
class AIService: ObservableObject {
    enum ConnectionState { case disconnected, connecting, connected }
    @Published private(set) var connectionState: ConnectionState = .disconnected
    nonisolated static let shared = AIService()

    private let baseURL: String
    private let session: URLSession

    nonisolated init(session: URLSession? = nil, baseURL: String = ServerConfig.baseURL) {
        self.baseURL = baseURL
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
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
        guard let url = URL(string: baseURL + path) else {
            print("[AIService] Bad URL: \(baseURL + path)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[AIService] POST \(path) error: \(error)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
                print("[AIService] POST \(path) status: \(http.statusCode) body: \(body.prefix(200))")
            }
        }.resume()
    }

    /// Notify server of session start.
    func connectStrokeSession(sessionId: String, documentName: String? = nil, questionNumber: Int? = nil) {
        print("[AIService] connectStrokeSession session=\(sessionId.prefix(8)) doc=\(documentName ?? "nil") q=\(questionNumber ?? -1)")
        currentSessionId = sessionId
        Task { @MainActor in self.connectionState = .connecting }
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
        Task { @MainActor in self.connectionState = .disconnected }
    }

    /// Sends stroke point data for a page to the server for logging.
    func sendStrokes(sessionId: String, page: Int, strokes: [[[String: Double]]], eventType: String = "draw", deletedCount: Int = 0, partLabel: String? = nil, contentMode: String? = nil) {
        var body: [String: Any] = [
            "session_id": sessionId,
            "user_id": KeychainService.get(.userIdentifier) ?? "",
            "page": page,
            "strokes": strokes.map { ["points": $0] },
            "event_type": eventType
        ]
        if deletedCount > 0 { body["deleted_count"] = deletedCount }
        if let part = partLabel { body["part_label"] = part }
        if let mode = contentMode { body["content_mode"] = mode }
        postJSON(path: "/api/strokes", body: body)
    }

    /// Sends a clear command for a session+page, deleting those logs from the DB.
    func sendClear(sessionId: String, page: Int) {
        postJSON(path: "/api/strokes/clear", body: ["session_id": sessionId, "page": page])
    }

    // MARK: - SSE Client (replaces reasoning WebSocket)

    private var sseTask: Task<Void, Never>?
    private var sseSessionId: String?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var currentTTSSampleRate: Double = 24000

    /// URLSession with long timeouts for SSE streaming.
    private lazy var sseSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 0  // no resource timeout
        return URLSession(configuration: config)
    }()

    /// Connect to the SSE event stream to receive reasoning results and TTS notifications.
    func connectSSE(sessionId: String) {
        // If already connected to a different session, disconnect first
        if sseTask != nil {
            if sseSessionId == sessionId { return }
            print("[SSE] Switching session: \(sseSessionId?.prefix(8) ?? "nil") → \(sessionId.prefix(8))")
            disconnectSSE()
        }
        sseSessionId = sessionId

        guard let url = URL(string: baseURL + "/api/events?session_id=\(sessionId)") else {
            print("[SSE] Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        print("[SSE] Connecting for session=\(sessionId.prefix(8))...")

        sseTask = Task { [weak self] in
            var backoff: UInt64 = 1_000_000_000  // 1s
            let maxBackoff: UInt64 = 30_000_000_000  // 30s

            while !Task.isCancelled {
                do {
                    guard let self = self else { return }
                    let (bytes, response) = try await self.sseSession.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                        print("[SSE] Bad status \(code), retrying in \(backoff / 1_000_000_000)s")
                        self.connectionState = .connecting
                        try await Task.sleep(nanoseconds: backoff)
                        backoff = min(backoff * 2, maxBackoff)
                        continue
                    }

                    backoff = 1_000_000_000  // reset on successful connect
                    print("[SSE] Connected for session=\(sessionId.prefix(8))...")

                    var parser = SSEParser()

                    for try await line in bytes.lines {
                        if line == ": connected" {
                            self.connectionState = .connected
                        }
                        if let event = parser.parseLine(line) {
                            await self.handleSSEEvent(type: event.type, data: event.data)
                        }
                    }
                } catch {
                    if Task.isCancelled { break }
                    print("[SSE] Error: \(error), reconnecting in \(backoff / 1_000_000_000)s")
                    self?.connectionState = .connecting
                    try? await Task.sleep(nanoseconds: backoff)
                    backoff = min(backoff * 2, maxBackoff)
                }
            }
        }
    }

    /// Disconnect the SSE event stream.
    func disconnectSSE() {
        sseTask?.cancel()
        sseTask = nil
        sseSessionId = nil
        Task { @MainActor in self.connectionState = .disconnected }
        stopAudioPlayback()
    }

    /// Handle a parsed SSE event.
    private func handleSSEEvent(type: String, data: String) async {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        if type == "reasoning" {
            let message = json["message"] as? String ?? ""
            let ttsId = json["tts_id"] as? String
            print("[SSE] Reasoning: \(message.prefix(80))")

            if let ttsId = ttsId {
                await fetchTTSStream(ttsId: ttsId)
            }
        }
    }

    // MARK: - HTTP TTS Streaming

    /// Fetch and play TTS audio stream from the server.
    private func fetchTTSStream(ttsId: String) async {
        guard let url = URL(string: baseURL + "/api/tts/stream/\(ttsId)") else { return }

        print("[TTS] Fetching stream for tts_id=\(ttsId.prefix(8))...")

        do {
            let (bytes, response) = try await sseSession.bytes(for: URLRequest(url: url))
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[TTS] Bad status for tts_id=\(ttsId.prefix(8))...")
                return
            }

            let sampleRate = Double(httpResponse.value(forHTTPHeaderField: "X-Sample-Rate") ?? "24000") ?? 24000
            startAudioPlayback(sampleRate: sampleRate)

            // Read chunks and feed to audio player
            var buffer = Data()
            let chunkSize = 8192
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= chunkSize {
                    playAudioChunk(buffer)
                    buffer = Data()
                }
            }
            // Flush remaining bytes
            if !buffer.isEmpty {
                playAudioChunk(buffer)
            }
            print("[TTS] Stream complete for tts_id=\(ttsId.prefix(8))...")

        } catch {
            print("[TTS] Stream error: \(error)")
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
            print("[TTS] Failed to create audio format")
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
            print("[TTS] Audio playback started")
        } catch {
            print("[TTS] Failed to start audio: \(error)")
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

    // MARK: - Voice REST (replaces voice WebSocket)

    /// Send recorded audio as a voice question. Transcription returns immediately;
    /// reasoning result arrives via SSE with a tts_id for audio streaming.
    func sendVoiceQuestion(audioData: Data, sessionId: String, page: Int) {
        print("[Voice] sendVoiceQuestion — \(audioData.count) bytes, session=\(sessionId.prefix(8))...")

        guard let url = URL(string: baseURL + "/api/voice/question") else {
            print("[Voice] Invalid URL")
            return
        }

        let userId = KeychainService.get(.userIdentifier) ?? ""
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("session_id", sessionId)
        appendField("user_id", userId)
        appendField("page", "\(page)")

        // Audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Fire-and-forget — reasoning arrives via SSE
        session.dataTask(with: request) { data, _, error in
            if let error = error {
                print("[Voice] Question POST error: \(error)")
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let transcription = json["transcription"] as? String {
                print("[Voice] Question transcription: \(transcription.prefix(80))")
            }
        }.resume()
    }

}
