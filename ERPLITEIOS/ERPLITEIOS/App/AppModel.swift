//
//  AppModel.swift
//  ERPLITEIOS
//

import Foundation
import Observation

enum AppPhase: Equatable {
    case launching
    case signedOut
    case sessionExpired
    case authenticated(Session)
    case failed(message: String, allowsMockSignIn: Bool)
}

@Observable
final class AppModel {
    private(set) var phase: AppPhase = .launching
    let dependencies: AppDependencies
    private var didBootstrap = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        phase = .launching

        if ProcessInfo.processInfo.arguments.contains("--reset-session") {
            try? dependencies.tokenStore.clear()
        }

        if let loadError = dependencies.configuration.loadError {
            phase = .failed(
                message: loadError.errorDescription ?? "The app configuration could not be read.",
                allowsMockSignIn: false
            )
            return
        }

        await restoreAuthenticatedSession()
    }

    func retryBootstrap() async {
        didBootstrap = false
        await bootstrap()
    }

    func refreshSessionIfNeeded() async {
        guard didBootstrap else { return }
        guard case .authenticated = phase else { return }
        await restoreAuthenticatedSession()
    }

    func signIn(username: String, password: String) async throws {
        let session = try await dependencies.authService.login(username: username, password: password)
        phase = .authenticated(session)
    }

    func signOut() async {
        await dependencies.authService.logout()
        phase = .signedOut
    }

    func discardSavedSession() async {
        try? dependencies.tokenStore.clear()
        phase = .signedOut
    }

    #if DEBUG
    func installPreviewPhase(_ phase: AppPhase) {
        self.phase = phase
        didBootstrap = true
    }
    #endif

    private func restoreAuthenticatedSession() async {
        do {
            if let session = try await dependencies.authService.restoreSession() {
                phase = .authenticated(session)
            } else if case .authenticated = phase {
                phase = .signedOut
            } else if case .launching = phase {
                phase = .signedOut
            }
        } catch AuthError.sessionExpired {
            phase = .sessionExpired
        } catch {
            phase = .failed(
                message: (error as? LocalizedError)?.errorDescription ?? "The saved session could not be read.",
                allowsMockSignIn: true
            )
        }
    }
}
