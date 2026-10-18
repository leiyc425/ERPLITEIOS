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

    func check() async throws -> HealthReport {
        guard configuration.baseURL != nil else {
            throw APIError.backendNotConfigured
        }
        let status = try await client.send(
            HTTPRequest(
                method: .get,
                path: "health",
                requiresAuthentication: false,
                versionPrefix: "",
                trailingSlash: true
            ),
            as: HealthStatus.self
        )
        return HealthReport(status: status, origin: .backend)
    }
}
