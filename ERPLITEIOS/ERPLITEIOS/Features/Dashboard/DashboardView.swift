//
//  DashboardView.swift
//  ERPLITEIOS
//

import SwiftUI

struct DashboardView: View {
    private let viewModel: DashboardViewModel
    private let signOut: () async -> Void

    init(
        session: Session,
        configuration: AppConfiguration,
        signOut: @escaping () async -> Void
    ) {
        viewModel = DashboardViewModel(session: session, configuration: configuration)
        self.signOut = signOut
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FlowmagikHeader(title: "Dashboard")
                    if viewModel.showsMockBanner {
                        MockDataBanner(
                            message: "Mock data. These placeholders did not come from the ERP Lite backend."
                        )
                    }
                }

                Section("Session") {
                    Text(viewModel.accountLine)
                    if let expiresAt = viewModel.session.expiresAt {
                        LabeledContent("Mock expiry") {
                            Text(expiresAt, format: .dateTime.hour().minute().day().month())
                        }
                    }
                }

                Section("Backend") {
                    Text(viewModel.backendTitle)
                        .font(.headline)
                    Text(viewModel.backendDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(viewModel.configuration.contractIntegrated ? "Contract integrated" : "No API contract integrated")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Modules") {
                    ForEach(viewModel.modules) { module in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(module.title)
                                Spacer()
                                if module.origin == .mock {
                                    Text("MOCK")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.mockForeground)
                                }
                            }
                            Text(module.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        Task { await signOut() }
                    }
                    .accessibilityIdentifier("dashboard.signOut")
                }
            }
        }
        .accessibilityIdentifier("dashboard.root")
    }
}
