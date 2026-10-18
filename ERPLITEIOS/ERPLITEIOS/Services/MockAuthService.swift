//
//  MockAuthService.swift
//  ERPLITEIOS
//

import Foundation

/// Local sign-in used until ERP Lite publishes an authentication contract.
/// Passwords are checked only for emptiness and are never stored or transmitted.
final class MockAuthService: AuthServicing {
    /// Placeholder lifetime for the on-device mock session. ERP Lite has not defined this.
    static let mockSessionLifetime: TimeInterval = 8 * 60 * 60

    private let tokenStore: any TokenStoring
    private let clock: any DateProviding
    private let sessionLifetime: TimeInterval
    private let simulatedDelay: Duration

    init(
        tokenStore: any TokenStoring,
        clock: any DateProviding,
        sessionLifetime: TimeInterval = MockAuthService.mockSessionLifetime,
        simulatedDelay: Duration = .zero
    ) {
        self.tokenStore = tokenStore
        self.clock = clock
        self.sessionLifetime = sessionLifetime
        self.simulatedDelay = simulatedDelay
    }

    func login(username: String, password: String) async throws -> Session {
        let label = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !password.isEmpty else {
            throw AuthError.missingCredentials
        }
        guard label.count <= 80, password.count <= 256 else {
            throw AuthError.inputTooLong
        }

        if simulatedDelay > .zero {
            try await Task.sleep(for: simulatedDelay)
        }

        let expiresAt = clock.now().addingTimeInterval(sessionLifetime)
        let credential = StoredCredential(
            secret: "mock-session-\(UUID().uuidString)",
            accountLabel: label,
            expiresAt: expiresAt,
            isMock: true
        )
        do {
            try tokenStore.save(credential)
        } catch {
            throw AuthError.storageFailed
        }
        return Session(accountLabel: label, expiresAt: expiresAt, isMock: true)
    }

    func logout() async {
        try? tokenStore.clear()
    }

    func restoreSession() async throws -> Session? {
        let stored: StoredCredential?
        do {
            stored = try tokenStore.load()
        } catch KeychainError.invalidData {
            try? tokenStore.clear()
            throw AuthError.storageFailed
        } catch {
            throw AuthError.storageFailed
        }

        guard let stored else {
            return nil
        }
        if let expiresAt = stored.expiresAt, expiresAt <= clock.now() {
            try? tokenStore.clear()
            throw AuthError.sessionExpired
        }
        return Session(
            accountLabel: stored.accountLabel,
            expiresAt: stored.expiresAt,
            isMock: stored.isMock
        )
    }
}
