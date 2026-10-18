//
//  CatalogListViewModels.swift
//  ERPLITEIOS
//

import Foundation
import Observation

@Observable
final class InventoryListViewModel {
    private let records: any ERPReading
    private(set) var items: [InventoryItemRecord] = []
    private(set) var skus: [SKUProductRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle

    init(records: any ERPReading) {
        self.records = records
    }

    func load() async {
        await loadCatalog { catalog in
            items = catalog.inventory
            skus = catalog.skus
            origin = catalog.origin
            state = items.isEmpty && skus.isEmpty ? .empty : .loaded
        }
    }

    private func loadCatalog(_ apply: (ERPCatalog) -> Void) async {
        state = .loading
        do {
            apply(try await records.loadCatalog())
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class ClientListViewModel {
    private let records: any ERPReading
    private(set) var clients: [ClientRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle

    init(records: any ERPReading) {
        self.records = records
    }

    func load() async {
        state = .loading
        do {
            let catalog = try await records.loadCatalog()
            clients = catalog.clients
            origin = catalog.origin
            state = clients.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class SaleListViewModel {
    private let records: any ERPReading
    private(set) var sales: [SaleRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle

    init(records: any ERPReading) {
        self.records = records
    }

    func load() async {
        state = .loading
        do {
            let catalog = try await records.loadCatalog()
            sales = catalog.sales
            origin = catalog.origin
            state = sales.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class InvoiceListViewModel {
    private let records: any ERPReading
    private(set) var invoices: [InvoiceRecord] = []
    private(set) var sales: [SaleRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle

    init(records: any ERPReading) {
        self.records = records
    }

    func load() async {
        state = .loading
        do {
            let catalog = try await records.loadCatalog()
            invoices = catalog.invoices
            sales = catalog.sales
            origin = catalog.origin
            state = invoices.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }

    func amountPaid(for invoice: InvoiceRecord) -> Decimal {
        sales.first { $0.id == invoice.saleID }?.amountPaid ?? .zero
    }
}
