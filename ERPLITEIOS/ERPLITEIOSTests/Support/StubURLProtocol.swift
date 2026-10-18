import Foundation
@testable import ERPLITEIOS

/// Records a header captured on URLSession's callback thread.
final class HeaderBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    func set(_ value: String?) {
        lock.lock()
        stored = value
        lock.unlock()
    }

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

/// Records whether a stub was hit. Safe to touch from URLSession's callback thread.
final class RequestFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func mark() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isMarked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var status: Int
        var body: Data
        var headers: [String: String]
    }

    private static let lock = NSLock()
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Response)?

    static func setHandler(_ handler: (@Sendable (URLRequest) throws -> Response)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let stub = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: stub.status,
                    httpVersion: "HTTP/1.1",
                    headerFields: stub.headers
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
