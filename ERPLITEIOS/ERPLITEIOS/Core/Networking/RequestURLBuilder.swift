//
//  RequestURLBuilder.swift
//  ERPLITEIOS
//

import Foundation

/// Joins a configured base URL, an optional version prefix, and a relative path.
/// The prefix is a hook for a future contract. Phase 0 does not define ERP Lite routes.
enum RequestURLBuilder {
    static func url(
        baseURL: URL,
        path: String,
        versionPrefix: String?,
        query: [URLQueryItem],
        trailingSlash: Bool = false
    ) throws -> URL {
        let pathSegments = try segments(from: path)
        let prefixSegments = try segments(from: versionPrefix ?? "")
        var url = baseURL
        for segment in prefixSegments + pathSegments {
            url.appendPathComponent(segment)
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequestURL
        }
        if trailingSlash, !components.path.hasSuffix("/") {
            components.path = components.path + "/"
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let built = components.url else {
            throw APIError.invalidRequestURL
        }
        return built
    }

    private static func segments(from raw: String) throws -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return []
        }
        if trimmed.contains("://") || trimmed.contains("\\") || trimmed.contains("..") {
            throw APIError.invalidRequestURL
        }

        var normalized = trimmed
        while normalized.hasPrefix("/") {
            normalized.removeFirst()
        }
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        if normalized.isEmpty || normalized.contains("//") {
            throw APIError.invalidRequestURL
        }

        let parts = normalized.split(separator: "/").map(String.init)
        if parts.isEmpty || parts.contains(".") || parts.contains(where: \.isEmpty) {
            throw APIError.invalidRequestURL
        }
        return parts
    }
}
