//
//  AppDependencies.swift
//  ERPLITEIOS
//

import Foundation

/// Composition root. Tests and previews pass their own stores and clocks.
struct AppDependencies {
    var configuration: AppConfiguration
    var tokenStore: any TokenStoring
    var authService: any AuthServicing
    var httpClient: any HTTPClientProtocol
    var clock: any DateProviding
    var records: any ERPProviding
    var health: any HealthChecking
    var connection: ConnectionSettings
    var shell: AppShellState = AppShellState()
    var readCache: ProtectedMemoryCache = ProtectedMemoryCache()

    static func live(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppDependencies {
        let configuration: AppConfiguration
        switch AppConfigurationLoader.load(bundle: bundle, environment: environment) {
        case .success(let loaded):
            configuration = loaded
        case .failure(let error):
            configuration = AppConfiguration(
                baseURL: nil,
                apiVersionPrefix: nil,
                requestTimeout: 30,
                loadError: error
            )
        }

        let tokenStore = KeychainTokenStore()
        let clock = SystemDateProvider()
        let authService = MockAuthService(
            tokenStore: tokenStore,
            clock: clock,
            simulatedDelay: .milliseconds(300)
        )
        let httpClient = URLSessionHTTPClient(
            configuration: configuration,
            authorizer: PendingContractAuthorizer()
        )
        let connection = ConnectionSettings(
            bundled: configuration,
            store: UserDefaultsEndpointStore()
        )
        return AppDependencies(
            configuration: configuration,
            tokenStore: tokenStore,
            authService: authService,
            httpClient: httpClient,
            clock: clock,
            records: MockERPReader(catalog: .sample),
            health: LiveHealthCheck(configuration: configuration, client: httpClient, endpoint: connection),
            connection: connection
        )
    }

    static func preview() -> AppDependencies {
        let configuration = AppConfiguration.mockDefault
        let tokenStore = InMemoryTokenStore()
        let clock = SystemDateProvider()
        let authService = MockAuthService(tokenStore: tokenStore, clock: clock)
        let httpClient = URLSessionHTTPClient(
            configuration: configuration,
            authorizer: PendingContractAuthorizer()
        )
        let connection = ConnectionSettings(bundled: configuration, store: MemoryEndpointStore())
        return AppDependencies(
            configuration: configuration,
            tokenStore: tokenStore,
            authService: authService,
            httpClient: httpClient,
            clock: clock,
            records: MockERPReader(catalog: .sample),
            health: LiveHealthCheck(configuration: configuration, client: httpClient, endpoint: connection),
            connection: connection
        )
    }
}
