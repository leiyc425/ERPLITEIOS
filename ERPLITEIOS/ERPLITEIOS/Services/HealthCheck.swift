//
//  HealthCheck.swift
//  ERPLITEIOS
//

import Foundation

protocol HealthChecking {
    func check() async throws -> HealthReport
}

/// Calls the only verified JSON route: `GET /health/` at the site root.
/// The path is not placed under an API version prefix.
struct LiveHealthCheck: HealthChecking {
    var configuration: AppConfiguration
    var client: any HTTPClientProtocol
    var endpoint: ConnectionSettings?

    func check() async throws -> HealthReport {
        let baseURL = endpoint?.effectiveBaseURL ?? configuration.baseURL
        guard let baseURL else {
            throw APIError.backendNotConfigured
        }
        let status = try await client.send(
            HTTPRequest(
                method: .get,
                path: "health",
                requiresAuthentication: false,
                versionPrefix: "",
                trailingSlash: true,
                baseURLOverride: baseURL
            ),
            as: HealthStatus.self
        )
        return HealthReport(status: status, origin: .backend)
    }
}
