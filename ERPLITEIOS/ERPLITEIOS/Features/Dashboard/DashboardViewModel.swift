//
//  DashboardViewModel.swift
//  ERPLITEIOS
//

import Foundation
import Observation

struct DashboardModule: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var origin: DataOrigin
}

@Observable
final class DashboardViewModel {
    var session: Session
    var configuration: AppConfiguration
    private let records: any DashboardProviding

    private(set) var state: ResourceLoadState = .idle
    private(set) var catalog: ERPCatalog?

    init(
        session: Session,
        configuration: AppConfiguration,
        records: any DashboardProviding
    ) {
        self.session = session
        self.configuration = configuration
        self.records = records
    }

    var showsMockBanner: Bool {
        catalog?.origin != .backend
    }

    var accountLine: String {
        if session.isMock {
            return "\(session.accountLabel) · mock session"
        }
        return "\(session.accountLabel) · backend session"
    }

    var backendTitle: String {
        if configuration.baseURL == nil {
            return "Launch URL not set"
        }
        return "Launch URL configured"
    }

    var backendDetail: String {
        "Business lists are mock samples. Settings can send GET /health/ when a base URL is saved. A successful health check does not enable those lists."
    }

    var modules: [DashboardModule] {
        [
            DashboardModule(
                id: "inventory",
                title: "Inventory",
                detail: "Physical units and a separate quantity SKU catalog.",
                origin: .mock
            ),
            DashboardModule(
                id: "clients",
                title: "Clients",
                detail: "ERP Lite clients. There is no Customer table.",
                origin: .mock
            ),
            DashboardModule(
                id: "sales",
                title: "Sales",
                detail: "A Sale is the transaction. There is no separate order.",
                origin: .mock
            ),
            DashboardModule(
                id: "invoices",
                title: "Invoices",
                detail: "Billing invoices. A Sale is not the invoice document.",
                origin: .mock
            ),
        ]
    }

    var inStockCount: Int { catalog?.inventory.filter { $0.status == .inStock }.count ?? 0 }
    var reservedCount: Int { catalog?.inventory.filter { $0.status == .reserved }.count ?? 0 }
    var soldCount: Int { catalog?.inventory.filter { $0.status == .sold }.count ?? 0 }
    var clientCount: Int { catalog?.clients.count ?? 0 }
    var saleCount: Int { catalog?.sales.count ?? 0 }
    var unpaidSaleCount: Int { catalog?.sales.filter { $0.paymentStatus == .unpaid }.count ?? 0 }
    var issuedBalanceDue: Decimal {
        guard let catalog else { return .zero }
        return catalog.invoices.reduce(Decimal.zero) { partial, invoice in
            guard invoice.status == .issued else { return partial }
            let paid = catalog.sales.first { $0.id == invoice.saleID }?.amountPaid ?? .zero
            return partial + (invoice.balanceDue(amountPaidOnSale: paid) ?? .zero)
        }
    }

    var skuAvailable: Int { catalog?.skus.reduce(0) { $0 + $1.available } ?? 0 }

    func load() async {
        state = .loading
        do {
            let loaded = try await records.loadDashboard()
            catalog = loaded
            let isEmpty = loaded.inventory.isEmpty
                && loaded.skus.isEmpty
                && loaded.clients.isEmpty
                && loaded.sales.isEmpty
                && loaded.invoices.isEmpty
            state = isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The dashboard could not be loaded.")
        }
    }
}
