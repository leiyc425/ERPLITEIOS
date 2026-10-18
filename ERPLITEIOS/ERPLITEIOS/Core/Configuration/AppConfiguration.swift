//
//  AppConfiguration.swift
//  ERPLITEIOS
//

import Foundation

/// Environment keys a developer can set for a future ERP Lite HTTP contract.
/// None of these are credentials. Leave them unset until a contract exists.
enum ConfigurationKey {
    static let baseURL = "ERPLITE_API_BASE_URL"
    static let versionPrefix = "ERPLITE_API_VERSION_PREFIX"
    static let timeout = "ERPLITE_API_TIMEOUT_SECONDS"
}

enum ConfigurationError: Error, Equatable, LocalizedError {
    case unreadableFile
    case invalidBaseURL
    case invalidTimeout
    case invalidVersionPrefix

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "BackendConfiguration.json could not be read."
        case .invalidBaseURL:
            return "The backend base URL must be an http or https URL without a username, password, query, or fragment."
        case .invalidTimeout:
            return "The request timeout must be a number of seconds from 1 through 180."
        case .invalidVersionPrefix:
            return "The API version prefix must be a short path such as api/v1, with no .. segments."
        }
    }
}

struct BundledBackendSettings: Codable, Equatable {
    var baseURL: String
    var apiVersionPrefix: String
    var requestTimeoutSeconds: Double

    init(baseURL: String = "", apiVersionPrefix: String = "", requestTimeoutSeconds: Double = 30) {
        self.baseURL = baseURL
        self.apiVersionPrefix = apiVersionPrefix
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }
}

/// Runtime configuration for the networking seam.
/// An empty base URL means the app stays on mock data. It does not imply a backend contract.
struct AppConfiguration: Equatable {
    var baseURL: URL?
    var apiVersionPrefix: String?
    var requestTimeout: TimeInterval
    var loadError: ConfigurationError?

    /// Phase 0 does not call ERP Lite. A saved base URL is not a working integration.
    var contractIntegrated: Bool { false }

    static let mockDefault = AppConfiguration(
        baseURL: nil,
        apiVersionPrefix: nil,
        requestTimeout: 30,
        loadError: nil
    )
}

enum AppConfigurationLoader {
    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Result<AppConfiguration, ConfigurationError> {
        let bundled: BundledBackendSettings
        if let url = configurationURL(in: bundle) {
            do {
                let data = try Data(contentsOf: url)
                bundled = try JSONDecoder().decode(BundledBackendSettings.self, from: data)
            } catch {
                return .failure(.unreadableFile)
            }
        } else {
            bundled = BundledBackendSettings()
        }
        return resolve(bundled: bundled, environment: environment)
    }

    static func resolve(
        bundled: BundledBackendSettings,
        environment: [String: String]
    ) -> Result<AppConfiguration, ConfigurationError> {
        let baseURLString = merged(bundled.baseURL, environment: environment, key: ConfigurationKey.baseURL)
        let prefixString = merged(bundled.apiVersionPrefix, environment: environment, key: ConfigurationKey.versionPrefix)

        let baseURL: URL?
        if baseURLString.isEmpty {
            baseURL = nil
        } else {
            switch makeBaseURL(baseURLString) {
            case .success(let url):
                baseURL = url
            case .failure(let error):
                return .failure(error)
            }
        }

        let prefix: String?
        switch makeVersionPrefix(prefixString) {
        case .success(let value):
            prefix = value
        case .failure(let error):
            return .failure(error)
        }

        let timeout: TimeInterval
        switch makeTimeout(bundled: bundled.requestTimeoutSeconds, environment: environment) {
        case .success(let value):
            timeout = value
        case .failure(let error):
            return .failure(error)
        }

        return .success(
            AppConfiguration(
                baseURL: baseURL,
                apiVersionPrefix: prefix,
                requestTimeout: timeout,
                loadError: nil
            )
        )
    }

    static func configurationURL(in bundle: Bundle) -> URL? {
        bundle.url(forResource: "BackendConfiguration", withExtension: "json")
            ?? bundle.url(forResource: "BackendConfiguration", withExtension: "json", subdirectory: "Resources")
    }

    private static func merged(_ bundled: String, environment: [String: String], key: String) -> String {
        let raw = environment[key] ?? bundled
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func makeBaseURL(_ raw: String) -> Result<URL, ConfigurationError> {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let url = components.url else {
            return .failure(.invalidBaseURL)
        }
        return .success(url)
    }

    static func makeVersionPrefix(_ raw: String) -> Result<String?, ConfigurationError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .success(nil)
        }
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/-_.")
        let containsIllegalCharacter = stripped.unicodeScalars.contains { !allowed.contains($0) }
        if stripped.isEmpty
            || stripped.count > 64
            || stripped.contains("..")
            || stripped.contains("//")
            || containsIllegalCharacter {
            return .failure(.invalidVersionPrefix)
        }
        return .success(stripped)
    }

    private static func makeTimeout(
        bundled: Double,
        environment: [String: String]
    ) -> Result<TimeInterval, ConfigurationError> {
        let value: Double
        if let raw = environment[ConfigurationKey.timeout] {
            guard let parsed = Double(raw) else {
                return .failure(.invalidTimeout)
            }
            value = parsed
        } else {
            value = bundled
        }
        guard value.isFinite, value >= 1, value <= 180 else {
            return .failure(.invalidTimeout)
        }
        return .success(value)
    }
}
