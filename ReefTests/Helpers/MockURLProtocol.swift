//
//  MockURLProtocol.swift
//  ReefTests
//
//  URLProtocol subclass for stubbing HTTP responses in tests.
//

import Foundation

final class MockURLProtocol: URLProtocol {
    static var handlers: [String: (Int, Data?, Error?)] = [:]
    static var defaultHandler: ((URLRequest) -> (Int, Data?, Error?))? = nil

    static func reset() {
        handlers = [:]
        defaultHandler = nil
    }

    static func stub(path: String, statusCode: Int = 200, data: Data?) {
        handlers[path] = (statusCode, data, nil)
    }

    static func stubError(path: String, error: Error) {
        handlers[path] = (0, nil, error)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""

        let (statusCode, data, error): (Int, Data?, Error?)
        if let handler = MockURLProtocol.handlers[path] {
            (statusCode, data, error) = handler
        } else if let fallback = MockURLProtocol.defaultHandler {
            (statusCode, data, error) = fallback(request)
        } else {
            (statusCode, data, error) = (404, nil, nil)
        }

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
