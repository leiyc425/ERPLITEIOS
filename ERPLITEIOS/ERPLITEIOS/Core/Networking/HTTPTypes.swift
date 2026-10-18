//
//  HTTPTypes.swift
//  ERPLITEIOS
//

import Foundation

enum HTTPMethod: String, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A relative request. Paths are not ERP Lite endpoints until a contract says they are.
struct HTTPRequest: Equatable {
    var method: HTTPMethod
    var path: String
    var query: [URLQueryItem]
    var headers: [String: String]
    var body: Data?
    var timeout: TimeInterval?
    var requiresAuthentication: Bool
    /// Overrides the configured version prefix for this call. Nil uses configuration.
    var versionPrefix: String?

    init(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval? = nil,
        requiresAuthentication: Bool = false,
        versionPrefix: String? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.requiresAuthentication = requiresAuthentication
        self.versionPrefix = versionPrefix
    }

    mutating func attachJSON<T: Encodable>(_ value: T) throws {
        body = try JSONCoding.encode(value)
        headers["Content-Type"] = "application/json"
    }
}

struct HTTPResponse: Equatable {
    var statusCode: Int
    var data: Data
    var headers: [String: String]
}

protocol HTTPClientProtocol {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

extension HTTPClientProtocol {
    func send<Response: Decodable>(_ request: HTTPRequest, as type: Response.Type) async throws -> Response {
        let response = try await send(request)
        do {
            return try JSONCoding.makeDecoder().decode(Response.self, from: response.data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed
        }
    }
}

/// Attaches credentials to a request once ERP Lite publishes an authentication scheme.
/// The live app uses an authorizer that refuses to attach anything.
protocol RequestAuthorizing {
    func authorize(_ request: inout URLRequest) async throws
}

/// Integration point that fails closed. It does not guess Bearer, cookies, or CSRF.
struct PendingContractAuthorizer: RequestAuthorizing {
    func authorize(_ request: inout URLRequest) async throws {
        throw APIError.authenticationSchemeNotConfigured
    }
}
