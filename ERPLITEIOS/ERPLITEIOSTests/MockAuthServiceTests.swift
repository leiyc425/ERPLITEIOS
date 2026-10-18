import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct MockAuthServiceTests {
    @Test func loginStoresAMockMarkerAndNotThePassword() async throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let store = InMemoryTokenStore()
        let auth = MockAuthService(tokenStore: store, clock: clock, sessionLifetime: 60)

        let session = try await auth.login(username: " Ada ", password: "local-only")
        #expect(session == Session(accountLabel: "Ada", expiresAt: clock.date.addingTimeInterval(60), isMock: true))

        let stored = try #require(try store.load())
        #expect(stored.isMock)
        #expect(stored.secret.hasPrefix("mock-session-"))
        #expect(!stored.secret.contains("local-only"))
        #expect(stored.accountLabel == "Ada")

        let restored = try await auth.restoreSession()
        #expect(restored == session)
    }

    @Test func rejectsEmptyCredentials() async {
        let auth = MockAuthService(tokenStore: InMemoryTokenStore(), clock: ManualClock(.now), sessionLifetime: 60)
        await #expect(throws: AuthError.missingCredentials) {
            try await auth.login(username: " ", password: "secret")
        }
        await #expect(throws: AuthError.missingCredentials) {
            try await auth.login(username: "ada", password: "")
        }
    }

    @Test func expiredSessionIsCleared() async throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let store = InMemoryTokenStore()
        let auth = MockAuthService(tokenStore: store, clock: clock, sessionLifetime: 30)
        _ = try await auth.login(username: "ada", password: "secret")
        clock.advance(by: 30)

        await #expect(throws: AuthError.sessionExpired) {
            try await auth.restoreSession()
        }
        #expect(try store.load() == nil)
    }

    @Test func logoutClearsTheStore() async throws {
        let store = InMemoryTokenStore()
        let auth = MockAuthService(tokenStore: store, clock: SystemDateProvider(), sessionLifetime: 60)
        _ = try await auth.login(username: "ada", password: "secret")
        await auth.logout()
        #expect(try store.load() == nil)
        let restored = try await auth.restoreSession()
        #expect(restored == nil)
    }
}
