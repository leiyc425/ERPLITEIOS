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

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
        sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout
        sessionConfiguration.waitsForConnectivity = false
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.httpCookieAcceptPolicy = .never
        let session = URLSession(configuration: sessionConfiguration)

        let tokenStore = KeychainTokenStore()
        let clock = SystemDateProvider()
        let authService = MockAuthService(
            tokenStore: tokenStore,
            clock: clock,
            simulatedDelay: .milliseconds(300)
        )
        let httpClient = URLSessionHTTPClient(
            configuration: configuration,
            session: session,
            authorizer: PendingContractAuthorizer()
        )
        return AppDependencies(
            configuration: configuration,
            tokenStore: tokenStore,
            authService: authService,
            httpClient: httpClient,
            clock: clock
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
        return AppDependencies(
            configuration: configuration,
            tokenStore: tokenStore,
            authService: authService,
            httpClient: httpClient,
            clock: clock
        )
    }
}
