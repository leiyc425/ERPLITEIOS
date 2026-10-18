//
//  DashboardView.swift
//  ERPLITEIOS
//

import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    private let records: any ERPReading
    private let signOut: () async -> Void

    init(
        session: Session,
        dependencies: AppDependencies,
        signOut: @escaping () async -> Void
    ) {
        records = dependencies.records
        self.signOut = signOut
        _viewModel = State(
            initialValue: DashboardViewModel(
                session: session,
                configuration: dependencies.configuration,
                records: dependencies.records,
                health: dependencies.health
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FlowmagikHeader(title: "Dashboard")
                    if viewModel.showsMockBanner {
                        MockDataBanner(
                            message: "Mock samples. Inventory, clients, and sales were not loaded from ERP Lite."
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
                    Text(viewModel.configuration.contractIntegrated ? "Contract integrated" : "Business lists are not a live API")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await viewModel.checkHealth() }
                    } label: {
                        if viewModel.isCheckingHealth {
                            ProgressView()
                        } else {
                            Text("Check backend health")
                        }
                    }
                    .accessibilityIdentifier("dashboard.health")
                    if let healthMessage = viewModel.healthMessage {
                        Text(healthMessage)
                            .font(.footnote)
                            .accessibilityIdentifier("dashboard.healthResult")
                    }
                }

                Section("Mock sample counts") {
                    switch viewModel.state {
                    case .idle, .loading:
                        ProgressView()
                    case .failed(let message):
                        Text(message)
                            .foregroundStyle(.red)
                        Button("Try again") {
                            Task { await viewModel.load() }
                        }
                    case .loaded, .empty:
                        LabeledContent("In stock", value: "\(viewModel.inStockCount)")
                        LabeledContent("Reserved", value: "\(viewModel.reservedCount)")
                        LabeledContent("Sold", value: "\(viewModel.soldCount)")
                        LabeledContent("Clients", value: "\(viewModel.clientCount)")
                        LabeledContent("Sales", value: "\(viewModel.saleCount)")
                        LabeledContent("Outstanding", value: Money.label(viewModel.outstanding))
                        Text("Server dashboard metrics such as gross profit are HTML-only and are not shown here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Records") {
                    ForEach(viewModel.modules) { module in
                        NavigationLink {
                            destination(for: module.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(module.title)
                                    Spacer()
                                    Text("MOCK")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.mockForeground)
                                }
                                Text(module.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("dashboard.\(module.id)")
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
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func destination(for id: String) -> some View {
        switch id {
        case "inventory":
            InventoryListView(records: records)
        case "clients":
            ClientListView(records: records)
        case "sales":
            SaleListView(records: records)
        case "invoices":
            InvoiceListView(records: records)
        default:
            Text("This module is not available.")
        }
    }
}
