//
//  SSEParser.swift
//  Reef
//
//  Parses Server-Sent Events (SSE) lines into typed events.
//

import Foundation

struct SSEEvent {
    let type: String
    let data: String

    func json() -> [String: Any]? {
        guard let jsonData = data.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    }
}

struct SSEParser {
    private var eventType = ""

    mutating func parseLine(_ line: String) -> SSEEvent? {
        if line.hasPrefix(":") || line.isEmpty {
            return nil
        } else if line.hasPrefix("event: ") {
            eventType = String(line.dropFirst(7))
            return nil
        } else if line.hasPrefix("data: ") {
            let data = String(line.dropFirst(6))
            let event = SSEEvent(type: eventType, data: data)
            eventType = ""
            return event
        }
        return nil
    }
}
