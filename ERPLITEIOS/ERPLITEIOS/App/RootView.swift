//
//  RootView.swift
//  ERPLITEIOS
//

import SwiftUI

struct RootView: View {
    var model: AppModel
    @State private var loginViewModel: LoginViewModel

    init(model: AppModel) {
        self.model = model
        _loginViewModel = State(
            initialValue: LoginViewModel { username, password in
                try await model.signIn(username: username, password: password)
            }
        )
    }

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                LoadingStateView(title: "Starting ERP Lite")
            case .signedOut, .sessionExpired:
                LoginView(
                    viewModel: loginViewModel,
                    notice: sessionNotice
                )
            case .authenticated(let session):
                DashboardView(
                    session: session,
                    configuration: model.dependencies.configuration
                ) {
                    await model.signOut()
                }
            case .failed(let message, let allowsMockSignIn):
                ErrorStateView(
                    title: "Could not start ERP Lite",
                    message: message,
                    retry: { Task { await model.retryBootstrap() } },
                    secondaryTitle: allowsMockSignIn ? "Continue to sign in" : nil,
                    secondary: allowsMockSignIn ? { Task { await model.discardSavedSession() } } : nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            await model.bootstrap()
        }
        .onChange(of: model.phase) { oldPhase, newPhase in
            guard case .authenticated = oldPhase else { return }
            switch newPhase {
            case .signedOut, .sessionExpired:
                loginViewModel.resetFields()
            default:
                break
            }
        }
    }

    private var sessionNotice: String? {
        if case .sessionExpired = model.phase {
            return AuthError.sessionExpired.errorDescription
        }
        return nil
    }
}

#if DEBUG
private func previewModel(_ phase: AppPhase) -> AppModel {
    let model = AppModel(dependencies: .preview())
    model.installPreviewPhase(phase)
    return model
}

#Preview("Login") {
    RootView(model: previewModel(.signedOut))
}

#Preview("Login Dark") {
    RootView(model: previewModel(.signedOut))
        .preferredColorScheme(.dark)
}

#Preview("Dashboard") {
    RootView(
        model: previewModel(
            .authenticated(Session(accountLabel: "Ada", expiresAt: nil, isMock: true))
        )
    )
}

#Preview("Expired") {
    RootView(model: previewModel(.sessionExpired))
}
#endif
