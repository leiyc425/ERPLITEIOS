//
//  LoginView.swift
//  ERPLITEIOS
//

import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: LoginViewModel
    var notice: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowmagikHeader(title: "ERP Lite")

                Text("Sign in")
                    .font(.title2.weight(.semibold))

                MockDataBanner(
                    message: "Mock authentication. Any non-empty username and password are accepted on this device. Nothing is sent to ERP Lite."
                )

                if let notice {
                    Text(notice)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("login.notice")
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $viewModel.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("login.username")

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("login.password")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("login.error")
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
                .accessibilityIdentifier("login.submit")

                Text("ERP Lite on the server remains the source of truth for accounts, permissions, and records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("login.root")
    }
}
