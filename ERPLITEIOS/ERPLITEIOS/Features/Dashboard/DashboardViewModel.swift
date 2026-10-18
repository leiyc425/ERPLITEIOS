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
    private let records: any ERPReading
    private let health: any HealthChecking

    private(set) var state: ResourceLoadState = .idle
    private(set) var catalog: ERPCatalog?
    private(set) var healthMessage: String?
    private(set) var isCheckingHealth = false

    init(
        session: Session,
        configuration: AppConfiguration,
        records: any ERPReading,
        health: any HealthChecking
    ) {
        self.session = session
        self.configuration = configuration
        self.records = records
        self.health = health
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
            return "Backend URL not set"
        }
        return "Base URL configured"
    }

    var backendDetail: String {
        if let baseURL = configuration.baseURL {
            return "\(baseURL.absoluteString) can receive GET /health/ only. Client, inventory, and sale lists are still mock samples."
        }
        return "No base URL is set, so GET /health/ is not sent. Client, inventory, and sale lists are mock samples."
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
    var outstanding: Decimal {
        catalog?.sales.reduce(Decimal.zero) { $0 + $1.outstandingBalance } ?? .zero
    }

    func load() async {
        state = .loading
        do {
            catalog = try await records.loadCatalog()
            state = .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The dashboard could not be loaded.")
        }
    }

    func checkHealth() async {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        defer { isCheckingHealth = false }
        do {
            let report = try await health.check()
            healthMessage = "\(report.status.status) · database \(report.status.database) · \(report.origin.rawValue)"
        } catch APIError.backendNotConfigured {
            healthMessage = "No base URL. GET /health/ was not sent."
        } catch {
            healthMessage = (error as? LocalizedError)?.errorDescription ?? "The health check failed."
        }
    }
}
