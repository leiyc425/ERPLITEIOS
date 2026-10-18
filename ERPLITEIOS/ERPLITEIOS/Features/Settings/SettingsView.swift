//
//  SettingsView.swift
//  ERPLITEIOS
//

import SwiftUI

@Observable
final class SettingsViewModel {
    var connection: ConnectionSettings
    private let health: any HealthChecking
    private(set) var healthMessage: String?
    private(set) var isCheckingHealth = false

    init(connection: ConnectionSettings, health: any HealthChecking) {
        self.connection = connection
        self.health = health
    }

    func checkHealth() async {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        defer { isCheckingHealth = false }
        do {
            let report = try await health.check()
            healthMessage = "\(report.status.status) · database \(report.status.database). Business lists stay on mock data."
        } catch APIError.backendNotConfigured {
            healthMessage = "No base URL. GET /health/ was not sent."
        } catch {
            healthMessage = (error as? LocalizedError)?.errorDescription ?? "The health check failed."
        }
    }
}

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    private let signOut: () async -> Void

    init(dependencies: AppDependencies, signOut: @escaping () async -> Void) {
        self.signOut = signOut
        _viewModel = State(
            initialValue: SettingsViewModel(
                connection: dependencies.connection,
                health: dependencies.health
            )
        )
    }

    var body: some View {
        Form {
            Section("Connection") {
                Text(viewModel.connection.modeSummary)
                    .font(.footnote)
                LabeledContent("Business data", value: "Mock")
                LabeledContent("Live request", value: "GET /health/ only")
                if let bundled = viewModel.connection.bundled.baseURL {
                    LabeledContent("Launch URL", value: bundled.absoluteString)
                } else {
                    Text("No launch URL is configured.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Development base URL") {
                TextField("https://example.com", text: viewModel.connection.draftBinding)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Development base URL")
                    .accessibilityIdentifier("settings.baseURL")
                Button("Save URL") {
                    viewModel.connection.saveDraft()
                }
                .accessibilityIdentifier("settings.save")
                Button("Clear saved URL") {
                    viewModel.connection.clear()
                }
                if let validationMessage = viewModel.connection.validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings.validation")
                }
                if let overrideURL = viewModel.connection.overrideURL {
                    Text("Saved for health checks: \(overrideURL.absoluteString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Health") {
                Button {
                    Task { await viewModel.checkHealth() }
                } label: {
                    if viewModel.isCheckingHealth {
                        ProgressView()
                    } else {
                        Text("Check backend health")
                    }
                }
                .accessibilityIdentifier("settings.health")
                .accessibilityHint("Sends GET /health/ only. Does not load business records.")
                if let healthMessage = viewModel.healthMessage {
                    Text(healthMessage)
                        .font(.footnote)
                        .accessibilityIdentifier("settings.healthResult")
                }
            }

            Section("Limits") {
                Text(viewModel.connection.limitationSummary)
                    .font(.footnote)
                    .accessibilityIdentifier("settings.limitations")
            }

            Section {
                Button("Sign out") {
                    Task { await signOut() }
                }
                .accessibilityIdentifier("settings.signOut")
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.root")
    }
}

private extension ConnectionSettings {
    var draftBinding: Binding<String> {
        Binding(
            get: { self.draft },
            set: { self.draft = $0 }
        )
    }
}
