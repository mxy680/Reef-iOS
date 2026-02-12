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
    private let baseURL = "http://172.20.83.12:8000"
    #else
    private let baseURL = "https://api.studyreef.com"
    #endif
    private let session: URLSession

    // MARK: - WebSocket state

    private var clusterSocket: URLSessionWebSocketTask?
    private var clusterCallback: ((_ page: Int, _ clusters: [[String: Any]]) -> Void)?
    private var reconnectAttempts: Int = 0
    private static let maxReconnectAttempts = 5

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

    // MARK: - Cluster WebSocket

    /// Connects to the cluster WebSocket endpoint.
    func connectClusterSocket() {
        guard clusterSocket == nil else { return }
        #if DEBUG
        guard let url = URL(string: "ws://172.20.83.12:8000/ws/cluster") else { return }
        #else
        guard let url = URL(string: "wss://api.studyreef.com/ws/cluster") else { return }
        #endif
        let task = session.webSocketTask(with: url)
        clusterSocket = task
        task.resume()
        reconnectAttempts = 0
        listenForClusterMessages()
    }

    /// Disconnects the cluster WebSocket.
    func disconnectClusterSocket() {
        clusterSocket?.cancel(with: .normalClosure, reason: nil)
        clusterSocket = nil
    }

    /// Sends stroke bounding boxes for a page to the server for clustering.
    func sendStrokeBounds(page: Int, strokes: [[String: CGFloat]]) {
        // Reconnect immediately if socket died between sends
        if clusterSocket == nil {
            connectClusterSocket()
        }
        guard let socket = clusterSocket else { return }

        let payload: [String: Any] = [
            "type": "stroke_bounds",
            "page": page,
            "strokes": strokes
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }

        socket.send(.string(text)) { [weak self] error in
            if let error = error {
                print("[AIService] WebSocket send error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.clusterSocket?.cancel(with: .abnormalClosure, reason: nil)
                    self?.clusterSocket = nil
                }
            }
        }
    }

    /// Registers a callback for cluster responses from the server.
    func onClusters(_ callback: @escaping (_ page: Int, _ clusters: [[String: Any]]) -> Void) {
        clusterCallback = callback
    }

    /// Recursive receive loop for cluster WebSocket messages.
    private func listenForClusterMessages() {
        clusterSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["type"] as? String == "clusters",
                       let page = json["page"] as? Int,
                       let clusters = json["clusters"] as? [[String: Any]] {
                        DispatchQueue.main.async {
                            self?.clusterCallback?(page, clusters)
                        }
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
                // Continue listening
                DispatchQueue.main.async {
                    self?.listenForClusterMessages()
                }

            case .failure(let error):
                print("[AIService] WebSocket receive error: \(error.localizedDescription)")
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.clusterSocket = nil
                    self.reconnectAttempts += 1
                    if self.reconnectAttempts <= Self.maxReconnectAttempts {
                        let delay = min(pow(2.0, Double(self.reconnectAttempts)), 30.0)
                        print("[AIService] WebSocket reconnect attempt \(self.reconnectAttempts)/\(Self.maxReconnectAttempts) in \(delay)s")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.connectClusterSocket()
                        }
                    } else {
                        print("[AIService] WebSocket max reconnect attempts reached, giving up")
                    }
                }
            }
        }
    }
}
