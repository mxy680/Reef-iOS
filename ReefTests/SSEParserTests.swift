//
//  SSEParserTests.swift
//  ReefTests
//
//  Tests for SSEParser SSE line parsing.
//

import Testing
import Foundation
@testable import Reef

@Suite("SSEParser", .serialized)
struct SSEParserTests {

    // MARK: - Comment and empty lines

    @Test("Comment line returns nil")
    func commentLineReturnsNil() {
        var parser = SSEParser()
        let result = parser.parseLine(": this is a comment")
        #expect(result == nil)
    }

    @Test("Empty line returns nil")
    func emptyLineReturnsNil() {
        var parser = SSEParser()
        let result = parser.parseLine("")
        #expect(result == nil)
    }

    // MARK: - event: lines

    @Test("event line returns nil but sets type for next data line")
    func eventLineReturnsNilAndSetsType() {
        var parser = SSEParser()
        let eventResult = parser.parseLine("event: reasoning")
        #expect(eventResult == nil)

        // The type should now be set — a subsequent data line should use it
        let dataResult = parser.parseLine("data: {}")
        #expect(dataResult != nil)
        #expect(dataResult?.type == "reasoning")
    }

    // MARK: - data: lines

    @Test("data line without prior event returns event with empty type")
    func dataLineWithoutPriorEventHasEmptyType() {
        var parser = SSEParser()
        let result = parser.parseLine("data: hello")
        #expect(result != nil)
        #expect(result?.type == "")
        #expect(result?.data == "hello")
    }

    @Test("event then data returns typed event")
    func eventThenDataReturnsTypedEvent() {
        var parser = SSEParser()
        _ = parser.parseLine("event: speak")
        let result = parser.parseLine("data: test payload")
        #expect(result != nil)
        #expect(result?.type == "speak")
        #expect(result?.data == "test payload")
    }

    // MARK: - Type reset

    @Test("Type resets to empty after data line is dispatched")
    func typeResetsAfterDispatch() {
        var parser = SSEParser()
        _ = parser.parseLine("event: speak")
        _ = parser.parseLine("data: first")

        // Second data line with no preceding event should have empty type
        let result = parser.parseLine("data: second")
        #expect(result != nil)
        #expect(result?.type == "")
        #expect(result?.data == "second")
    }

    // MARK: - Multiple event-data pairs

    @Test("Multiple event-data pairs work correctly in sequence")
    func multipleEventDataPairs() {
        var parser = SSEParser()

        _ = parser.parseLine("event: reasoning")
        let first = parser.parseLine("data: payload one")
        #expect(first?.type == "reasoning")
        #expect(first?.data == "payload one")

        _ = parser.parseLine("event: tts")
        let second = parser.parseLine("data: payload two")
        #expect(second?.type == "tts")
        #expect(second?.data == "payload two")
    }

    // MARK: - Unknown line format

    @Test("Unknown line format returns nil")
    func unknownLineFormatReturnsNil() {
        var parser = SSEParser()
        let result = parser.parseLine("retry: 3000")
        #expect(result == nil)
    }

    // MARK: - SSEEvent.json()

    @Test("json() with valid JSON object returns dictionary")
    func jsonWithValidObjectReturnsDictionary() {
        let event = SSEEvent(type: "speak", data: "{\"message\":\"hello\",\"tts_id\":\"abc\"}")
        let json = event.json()
        #expect(json != nil)
        #expect(json?["message"] as? String == "hello")
        #expect(json?["tts_id"] as? String == "abc")
    }

    @Test("json() with invalid JSON returns nil")
    func jsonWithInvalidJSONReturnsNil() {
        let event = SSEEvent(type: "speak", data: "not json at all")
        #expect(event.json() == nil)
    }

    @Test("json() with empty data returns nil")
    func jsonWithEmptyDataReturnsNil() {
        let event = SSEEvent(type: "", data: "")
        #expect(event.json() == nil)
    }
}
