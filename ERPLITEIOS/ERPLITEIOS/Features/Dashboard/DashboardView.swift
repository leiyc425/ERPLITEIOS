//
//  DashboardView.swift
//  ERPLITEIOS
//

import SwiftUI

struct DashboardView: View {
    var shell: AppShellState
    @State private var viewModel: DashboardViewModel
    @State private var showScan = false
    private let signOut: () async -> Void
    private let records: any ERPProviding
    private let clock: any DateProviding
    private let drafts: IntakeDraftStore

    init(
        session: Session,
        dependencies: AppDependencies,
        signOut: @escaping () async -> Void
    ) {
        shell = dependencies.shell
        self.signOut = signOut
        records = dependencies.records
        clock = dependencies.clock
        drafts = dependencies.intake
        _viewModel = State(
            initialValue: DashboardViewModel(
                session: session,
                configuration: dependencies.configuration,
                records: dependencies.records
            )
        )
    }

    var body: some View {
        List {
            Section {
                FlowmagikHeader(title: "Dashboard")
                if viewModel.showsMockBanner {
                    MockDataBanner(
                        message: "Mock samples. These counts were not loaded from ERP Lite."
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
            }

            Section("Mock sample counts") {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .accessibilityLabel("Loading dashboard")
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.red)
                    Button("Try again") {
                        Task { await viewModel.load() }
                    }
                case .empty:
                    Text("No sample records are loaded.")
                        .foregroundStyle(.secondary)
                case .loaded:
                    LabeledContent("Units in stock", value: "\(viewModel.inStockCount)")
                    LabeledContent("Units reserved", value: "\(viewModel.reservedCount)")
                    LabeledContent("Units sold", value: "\(viewModel.soldCount)")
                    LabeledContent("SKU available", value: "\(viewModel.skuAvailable)")
                    LabeledContent("Sales", value: "\(viewModel.saleCount)")
                    LabeledContent("Unpaid sales", value: "\(viewModel.unpaidSaleCount)")
                    LabeledContent("Issued balance due", value: Money.label(viewModel.issuedBalanceDue))
                    Text("Issued balance due adds stored invoice grand totals minus each sale’s payments. Drafts, void invoices, tax, profit, and COGS are not calculated here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Open") {
                ForEach(viewModel.modules) { module in
                    Button {
                        shell.tab = AppTab(moduleID: module.id)
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
                    .accessibilityLabel("Open \(module.title)")
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Scan") {
                    showScan = true
                }
                .accessibilityIdentifier("dashboard.scan")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign out") {
                    Task { await signOut() }
                }
                .accessibilityIdentifier("dashboard.signOut")
            }
        }
        .accessibilityIdentifier("dashboard.root")
        .task { await viewModel.load() }
        .sheet(isPresented: $showScan) {
            ScanSheet(records: records, drafts: drafts, clock: clock)
        }
    }
}

private struct ScanSheet: View {
    var records: any ERPProviding
    var drafts: IntakeDraftStore
    var clock: any DateProviding
    @State private var model: ScanWorkflowModel?

    var body: some View {
        Group {
            if let model {
                ScanWorkflowView(model: model)
            } else {
                ProgressView("Preparing scan")
                    .accessibilityIdentifier("scan.loading")
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard model == nil else { return }
        let resolver: any ScanResolving
        do {
            let catalog = try await records.loadCatalog()
            resolver = CatalogScanResolver(catalog: catalog)
        } catch {
            resolver = FailedScanResolver(message: "The sample catalog could not be loaded. No request was sent.")
        }
        model = ScanWorkflowModel(
            resolver: resolver,
            drafts: drafts,
            clock: clock,
            availability: DeviceScanner.availability
        )
    }
}
