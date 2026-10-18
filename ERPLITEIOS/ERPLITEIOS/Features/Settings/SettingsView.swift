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
    private var checkGeneration = 0

    init(connection: ConnectionSettings, health: any HealthChecking) {
        self.connection = connection
        self.health = health
    }

    func invalidateHealthResult() {
        checkGeneration += 1
        healthMessage = nil
        isCheckingHealth = false
    }

    func checkHealth() async {
        guard !isCheckingHealth else { return }
        checkGeneration += 1
        let generation = checkGeneration
        isCheckingHealth = true
        defer {
            if generation == checkGeneration {
                isCheckingHealth = false
            }
        }
        do {
            let report = try await health.check()
            guard generation == checkGeneration else { return }
            healthMessage = "\(report.status.status) · database \(report.status.database). Business lists stay on mock data."
        } catch {
            guard generation == checkGeneration else { return }
            healthMessage = Self.diagnostic(for: error)
        }
    }

    static func diagnostic(for error: Error) -> String {
        switch error as? APIError {
        case .backendNotConfigured:
            return "No base URL. GET /health/ was not sent."
        case .timedOut:
            return "The health check timed out."
        case .cancelled:
            return "The health check was cancelled."
        case .offline:
            return "The device appears to be offline."
        case .cannotReachHost:
            return "The server could not be reached."
        case .secureConnectionFailed:
            return "The secure connection failed. No cleartext exception was added."
        case .unacceptableStatus(let code):
            return "The server returned HTTP \(code). Business lists stay on mock data."
        case .decodingFailed:
            return "The health response was not valid JSON."
        case .invalidRequestURL:
            return "The health URL could not be built."
        default:
            return "The health check failed."
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
                        .accessibilityLabel(healthMessage)
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
        .onChange(of: viewModel.connection.revision) {
            viewModel.invalidateHealthResult()
        }
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
