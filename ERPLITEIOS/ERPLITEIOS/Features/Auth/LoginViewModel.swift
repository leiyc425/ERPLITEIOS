//
//  LoginViewModel.swift
//  ERPLITEIOS
//

import Foundation
import Observation

@Observable
final class LoginViewModel {
    var username = ""
    var password = ""
    var isSubmitting = false
    var errorMessage: String?

    private let signIn: (String, String) async throws -> Void

    init(signIn: @escaping (String, String) async throws -> Void) {
        self.signIn = signIn
    }

    var canSubmit: Bool {
        !isSubmitting
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    func submit() async {
        guard !isSubmitting else { return }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else {
            errorMessage = AuthError.missingCredentials.errorDescription
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await signIn(trimmedUsername, password)
            password = ""
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Sign in failed."
        }
    }

    func resetFields() {
        username = ""
        password = ""
        errorMessage = nil
        isSubmitting = false
    }
}
