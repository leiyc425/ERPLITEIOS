import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct AppModelTests {
    @Test func bootstrapSignsOutWhenNothingIsStored() async {
        let fixture = Fixture()
        await fixture.model.bootstrap()
        #expect(fixture.model.phase == .signedOut)
        #expect(fixture.trap.sendCount == 0)
    }

    @Test func signInAndSignOutStayOnTheDevice() async throws {
        let fixture = Fixture()
        await fixture.model.bootstrap()
        try await fixture.model.signIn(username: "ada", password: "secret")

        let expected = Session(
            accountLabel: "ada",
            expiresAt: fixture.clock.date.addingTimeInterval(60),
            isMock: true
        )
        #expect(fixture.model.phase == .authenticated(expected))
        #expect(fixture.trap.sendCount == 0)

        await fixture.model.signOut()
        #expect(fixture.model.phase == .signedOut)
        #expect(try fixture.store.load() == nil)
    }

    @Test func refreshExpiresAnOldMockSession() async throws {
        let fixture = Fixture()
        await fixture.model.bootstrap()
        try await fixture.model.signIn(username: "ada", password: "secret")
        fixture.clock.advance(by: 61)
        await fixture.model.refreshSessionIfNeeded()
        #expect(fixture.model.phase == .sessionExpired)
    }

    @Test func bootstrapReportsAnExpiredStoredSession() async throws {
        let fixture = Fixture()
        try fixture.store.save(
            StoredCredential(
                secret: "mock-session-old",
                accountLabel: "ada",
                expiresAt: fixture.clock.date.addingTimeInterval(-1),
                isMock: true
            )
        )
        await fixture.model.bootstrap()
        #expect(fixture.model.phase == .sessionExpired)
    }

    @Test func invalidConfigurationStopsLaunch() async {
        var configuration = AppConfiguration.mockDefault
        configuration.loadError = .invalidBaseURL
        let trap = TrapHTTPClient()
        let model = AppModel(
            dependencies: AppDependencies(
                configuration: configuration,
                tokenStore: InMemoryTokenStore(),
                authService: MockAuthService(tokenStore: InMemoryTokenStore(), clock: SystemDateProvider()),
                httpClient: trap,
                clock: SystemDateProvider()
            )
        )
        await model.bootstrap()
        #expect(
            model.phase == .failed(
                message: ConfigurationError.invalidBaseURL.errorDescription ?? "",
                allowsMockSignIn: false
            )
        )
        #expect(trap.sendCount == 0)
    }

    @MainActor
    private struct Fixture {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let store = InMemoryTokenStore()
        let trap = TrapHTTPClient()
        let model: AppModel

        init() {
            let auth = MockAuthService(tokenStore: store, clock: clock, sessionLifetime: 60)
            model = AppModel(
                dependencies: AppDependencies(
                    configuration: .mockDefault,
                    tokenStore: store,
                    authService: auth,
                    httpClient: trap,
                    clock: clock
                )
            )
        }
    }
}

@MainActor
private final class TrapHTTPClient: HTTPClientProtocol {
    var sendCount = 0

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        sendCount += 1
        throw APIError.backendNotConfigured
    }
}
