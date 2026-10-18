import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct ConfigurationTests {
    @Test func emptySettingsStayUnconfigured() throws {
        let configuration = try AppConfigurationLoader.resolve(
            bundled: BundledBackendSettings(),
            environment: [:]
        ).get()

        #expect(configuration.baseURL == nil)
        #expect(configuration.apiVersionPrefix == nil)
        #expect(configuration.requestTimeout == 30)
        #expect(configuration.contractIntegrated == false)
        #expect(configuration.loadError == nil)
    }

    @Test func environmentOverridesBundledURL() throws {
        let configuration = try AppConfigurationLoader.resolve(
            bundled: BundledBackendSettings(baseURL: "https://bundled.example.com"),
            environment: [ConfigurationKey.baseURL: "https://override.example.com/erp"]
        ).get()

        #expect(configuration.baseURL?.absoluteString == "https://override.example.com/erp")
    }

    @Test func blankEnvironmentClearsBundledURL() throws {
        let configuration = try AppConfigurationLoader.resolve(
            bundled: BundledBackendSettings(baseURL: "https://bundled.example.com"),
            environment: [ConfigurationKey.baseURL: " "]
        ).get()

        #expect(configuration.baseURL == nil)
    }

    @Test func rejectsCredentialsAndNonHTTPSchemes() {
        #expect(AppConfigurationLoader.makeBaseURL("ftp://example.com") == .failure(.invalidBaseURL))
        #expect(AppConfigurationLoader.makeBaseURL("https://user:secret@example.com") == .failure(.invalidBaseURL))
        #expect(AppConfigurationLoader.makeBaseURL("https://example.com/erp?token=secret") == .failure(.invalidBaseURL))
        #expect(AppConfigurationLoader.makeBaseURL("https://example.com#frag") == .failure(.invalidBaseURL))
    }

    @Test func rejectsUnsafeVersionPrefix() {
        #expect(AppConfigurationLoader.makeVersionPrefix("../v1") == .failure(.invalidVersionPrefix))
        #expect(AppConfigurationLoader.makeVersionPrefix("api//v1") == .failure(.invalidVersionPrefix))
        #expect(AppConfigurationLoader.makeVersionPrefix("api/v1") == .success("api/v1"))
        #expect(AppConfigurationLoader.makeVersionPrefix(" ") == .success(nil))
    }

    @Test func rejectsTimeoutOutsideTheSupportedRange() {
        let result = AppConfigurationLoader.resolve(
            bundled: BundledBackendSettings(),
            environment: [ConfigurationKey.timeout: "0"]
        )
        #expect(result == .failure(.invalidTimeout))
    }

    @Test func committedConfigurationDoesNotNameABackend() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ERPLITEIOS/Resources/BackendConfiguration.json")
        let data = try Data(contentsOf: file)
        let settings = try JSONDecoder().decode(BundledBackendSettings.self, from: data)
        #expect(settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(settings.apiVersionPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("http://"))
        #expect(!text.contains("https://"))
        #expect(!text.contains("192.168."))
        #expect(!text.contains("10."))
        #expect(!text.contains("172.16."))
        #expect(!text.contains("localhost"))
    }
}
