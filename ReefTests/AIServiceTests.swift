//
//  AIServiceTests.swift
//  ReefTests
//
//  Tests for AIService network layer using MockURLProtocol.
//

import Testing
@testable import Reef
import Foundation

@Suite("AIService", .serialized)
struct AIServiceTests {

    /// Create a URLSession that uses MockURLProtocol
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Create an AIService instance using mock session
    @MainActor
    private func makeService() -> AIService {
        MockURLProtocol.reset()
        return AIService(session: makeMockSession(), baseURL: "http://test.local")
    }

    // MARK: - Embed: Success

    @Test("embed success returns embeddings")
    func embed_success_returnsEmbeddings() async throws {
        let service = await makeService()

        let responseBody = AIEmbedResponse(
            embeddings: [[0.1, 0.2, 0.3]],
            model: "test",
            dimensions: 3,
            count: 1,
            mode: "real"
        )
        let data = try JSONEncoder().encode(responseBody)
        MockURLProtocol.stub(path: "/ai/embed", data: data)

        let result = try await service.embed(texts: ["hello"])
        #expect(result.count == 1)
        #expect(result[0] == [0.1, 0.2, 0.3])
    }

    // MARK: - Embed: Server Error

    @Test("embed server error throws AIServiceError")
    func embed_serverError_throwsServerError() async throws {
        let service = await makeService()

        let errorData = try JSONEncoder().encode(["detail": "Model not loaded"])
        MockURLProtocol.stub(path: "/ai/embed", statusCode: 503, data: errorData)

        await #expect(throws: AIServiceError.self) {
            _ = try await service.embed(texts: ["hello"])
        }
    }

    // MARK: - Embed: Network Error

    @Test("embed network error throws AIServiceError")
    func embed_networkError_throwsNetworkError() async throws {
        let service = await makeService()

        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        MockURLProtocol.stubError(path: "/ai/embed", error: networkError)

        await #expect(throws: AIServiceError.self) {
            _ = try await service.embed(texts: ["hello"])
        }
    }

    // MARK: - Embed: Invalid JSON Response

    @Test("embed invalid JSON throws error")
    func embed_invalidJSON_throwsDecodingError() async throws {
        let service = await makeService()

        MockURLProtocol.stub(path: "/ai/embed", data: "not json".data(using: .utf8))

        await #expect(throws: Error.self) {
            _ = try await service.embed(texts: ["hello"])
        }
    }

    // MARK: - Embed: Mock Mode URL

    @Test("embed mock mode appends query param")
    func embed_mockMode_appendsQueryParam() async throws {
        let service = await makeService()

        MockURLProtocol.defaultHandler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("mode=mock") {
                let response = AIEmbedResponse(embeddings: [[1.0]], model: "mock", dimensions: 1, count: 1, mode: "mock")
                let data = try! JSONEncoder().encode(response)
                return (200, data, nil)
            }
            return (404, nil, nil)
        }

        let result = try await service.embed(texts: ["test"], useMock: true)
        #expect(result.count == 1)
    }

    // MARK: - Embed: Request Body

    @Test("embed sends correct request body")
    func embed_sendsCorrectRequestBody() async throws {
        let service = await makeService()

        var capturedBody: Data? = nil
        MockURLProtocol.defaultHandler = { request in
            capturedBody = request.httpBody ?? request.httpBodyStream.flatMap { stream in
                stream.open()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                defer { buffer.deallocate() }
                var data = Data()
                while stream.hasBytesAvailable {
                    let count = stream.read(buffer, maxLength: 4096)
                    if count > 0 { data.append(buffer, count: count) }
                }
                stream.close()
                return data
            }
            let response = AIEmbedResponse(embeddings: [[0.0]], model: "test", dimensions: 1, count: 1, mode: "real")
            let data = try! JSONEncoder().encode(response)
            return (200, data, nil)
        }

        _ = try await service.embed(texts: ["hello world"], normalize: false)

        let body = try #require(capturedBody)
        let decoded = try JSONDecoder().decode(AIEmbedRequest.self, from: body)
        #expect(decoded.texts == ["hello world"])
        #expect(decoded.normalize == false)
    }
}
