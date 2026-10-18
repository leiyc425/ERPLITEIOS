//
//  HTTPClient.swift
//  ERPLITEIOS
//

import Foundation

/// URLSession client for a future ERP Lite contract.
/// It refuses to send when no base URL is configured, and it refuses to invent an auth scheme.
final class URLSessionHTTPClient: HTTPClientProtocol {
    private let baseURL: URL?
    private let versionPrefix: String?
    private let requestTimeout: TimeInterval
    private let session: URLSession
    private let redirectDelegate: HTTPRedirectDelegate
    private let authorizer: any RequestAuthorizing

    init(
        configuration: AppConfiguration,
        protocolClasses: [AnyClass] = [],
        authorizer: any RequestAuthorizing
    ) {
        self.baseURL = configuration.baseURL
        self.versionPrefix = configuration.apiVersionPrefix
        self.requestTimeout = configuration.requestTimeout
        self.authorizer = authorizer

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
        sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout
        sessionConfiguration.waitsForConnectivity = false
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.httpCookieAcceptPolicy = .never
        if !protocolClasses.isEmpty {
            sessionConfiguration.protocolClasses = protocolClasses
        }

        let redirectDelegate = HTTPRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        self.session = URLSession(
            configuration: sessionConfiguration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await send(request, attempt: 0)
    }

    /// GET may be sent once more after a timeout or a dropped connection. Other methods are not retried.
    private func send(_ request: HTTPRequest, attempt: Int) async throws -> HTTPResponse {
        do {
            return try await perform(request)
        } catch let error as APIError {
            let canRetry = attempt == 0 && request.method == .get && error.retriesGET
            guard canRetry else { throw error }
            try Task.checkCancellation()
            return try await send(request, attempt: 1)
        }
    }

    private func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let baseURL = request.baseURLOverride ?? baseURL else {
            throw APIError.backendNotConfigured
        }

        let url = try RequestURLBuilder.url(
            baseURL: baseURL,
            path: request.path,
            versionPrefix: request.versionPrefix ?? versionPrefix,
            query: request.query,
            trailingSlash: request.trailingSlash
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout ?? requestTimeout
        urlRequest.httpBody = request.body

        var headers = request.headers
        if request.body != nil && headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        if headers["Accept"] == nil {
            headers["Accept"] = "application/json"
        }
        for (field, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        if request.requiresAuthentication {
            try await authorizer.authorize(&urlRequest)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw APIError.classified(error)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport("")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("The server response was not HTTP.")
        }
        if http.statusCode == 401 {
            throw APIError.unauthenticated
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.unacceptableStatus(code: http.statusCode)
        }

        return HTTPResponse(
            statusCode: http.statusCode,
            data: data,
            headers: Self.headerMap(http)
        )
    }

    private static let sensitiveHeaders: Set<String> = [
        "authorization",
        "cookie",
        "proxy-authorization",
        "set-cookie",
    ]

    private static func headerMap(_ response: HTTPURLResponse) -> [String: String] {
        var map: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let field = key as? String else { continue }
            if sensitiveHeaders.contains(field.lowercased()) {
                continue
            }
            map[field] = String(describing: value)
        }
        return map
    }
}

/// Refuses every redirect so a 3xx response cannot move the request to another host.
final class HTTPRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
