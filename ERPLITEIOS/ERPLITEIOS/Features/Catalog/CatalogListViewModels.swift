//
//  CatalogListViewModels.swift
//  ERPLITEIOS
//

import Foundation
import Observation

enum UnitStatusFilter: String, CaseIterable, Identifiable {
    case all
    case inStock
    case reserved
    case sold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All statuses"
        case .inStock: "In Stock"
        case .reserved: "Reserved"
        case .sold: "Sold"
        }
    }

    var status: InventoryStatus? {
        switch self {
        case .all: nil
        case .inStock: .inStock
        case .reserved: .reserved
        case .sold: .sold
        }
    }
}

enum UnitSort: String, CaseIterable, Identifiable {
    case number
    case name
    case status

    var id: String { rawValue }

    var label: String {
        switch self {
        case .number: "Number"
        case .name: "Name"
        case .status: "Status"
        }
    }
}

enum SKUAvailabilityFilter: String, CaseIterable, Identifiable {
    case all
    case available
    case noneAvailable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All SKUs"
        case .available: "Available"
        case .noneAvailable: "None available"
        }
    }
}

enum SKUSort: String, CaseIterable, Identifiable {
    case code
    case name
    case available

    var id: String { rawValue }

    var label: String {
        switch self {
        case .code: "SKU"
        case .name: "Name"
        case .available: "Available"
        }
    }
}

enum InventoryBrowser {
    static func units(
        _ items: [InventoryItemRecord],
        query: String,
        status: UnitStatusFilter,
        sort: UnitSort
    ) -> [InventoryItemRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            let statusMatches = status.status == nil || item.status == status.status
            guard statusMatches else { return false }
            guard !needle.isEmpty else { return true }
            return [item.name, item.inventoryNumber, item.externalInventoryNumber].contains {
                $0.localizedStandardContains(needle)
            }
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .number:
                return lhs.inventoryNumber.localizedStandardCompare(rhs.inventoryNumber) == .orderedAscending
            case .name:
                if lhs.name.localizedStandardCompare(rhs.name) != .orderedSame {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.inventoryNumber.localizedStandardCompare(rhs.inventoryNumber) == .orderedAscending
            case .status:
                if lhs.status.label.localizedStandardCompare(rhs.status.label) != .orderedSame {
                    return lhs.status.label.localizedStandardCompare(rhs.status.label) == .orderedAscending
                }
                return lhs.inventoryNumber.localizedStandardCompare(rhs.inventoryNumber) == .orderedAscending
            }
        }
    }

    static func skus(
        _ items: [SKUProductRecord],
        query: String,
        availability: SKUAvailabilityFilter,
        sort: SKUSort
    ) -> [SKUProductRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            switch availability {
            case .all:
                break
            case .available:
                if item.available <= 0 { return false }
            case .noneAvailable:
                if item.available > 0 { return false }
            }
            guard !needle.isEmpty else { return true }
            return [item.name, item.sku].contains { $0.localizedStandardContains(needle) }
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .code:
                return lhs.sku.localizedStandardCompare(rhs.sku) == .orderedAscending
            case .name:
                if lhs.name.localizedStandardCompare(rhs.name) != .orderedSame {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sku.localizedStandardCompare(rhs.sku) == .orderedAscending
            case .available:
                if lhs.available != rhs.available {
                    return lhs.available > rhs.available
                }
                return lhs.sku.localizedStandardCompare(rhs.sku) == .orderedAscending
            }
        }
    }
}

enum RecordTitle {
    static func name(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled record" : trimmed
    }
}

enum RecordSearch {
    static func matches(_ query: String, fields: [String]) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return fields.contains { $0.localizedStandardContains(needle) }
    }
}

@Observable
final class InventoryListViewModel {
    private let records: any InventoryProviding
    private(set) var items: [InventoryItemRecord] = []
    private(set) var skus: [SKUProductRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle
    var unitQuery = ""
    var unitStatus: UnitStatusFilter = .all
    var unitSort: UnitSort = .number
    var skuQuery = ""
    var skuAvailability: SKUAvailabilityFilter = .all
    var skuSort: SKUSort = .code

    init(records: any InventoryProviding) {
        self.records = records
    }

    var filteredUnits: [InventoryItemRecord] {
        InventoryBrowser.units(items, query: unitQuery, status: unitStatus, sort: unitSort)
    }

    var filteredSKUs: [SKUProductRecord] {
        InventoryBrowser.skus(skus, query: skuQuery, availability: skuAvailability, sort: skuSort)
    }

    var unitsAreFiltered: Bool {
        !unitQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || unitStatus != .all
            || unitSort != .number
    }

    var skusAreFiltered: Bool {
        !skuQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || skuAvailability != .all
            || skuSort != .code
    }

    func resetUnits() {
        unitQuery = ""
        unitStatus = .all
        unitSort = .number
    }

    func resetSKUs() {
        skuQuery = ""
        skuAvailability = .all
        skuSort = .code
    }

    func load() async {
        guard state == .idle || state.isFailed else { return }
        await loadCatalog { snapshot in
            items = snapshot.units
            skus = snapshot.skus
            origin = snapshot.origin
            state = items.isEmpty && skus.isEmpty ? .empty : .loaded
        }
    }

    private func loadCatalog(_ apply: (InventorySnapshot) -> Void) async {
        state = .loading
        do {
            apply(try await records.loadInventory())
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class ClientListViewModel {
    private let records: any ClientProviding
    private(set) var clients: [ClientRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle
    var query = ""

    init(records: any ClientProviding) {
        self.records = records
    }

    var filteredClients: [ClientRecord] {
        clients.filter {
            RecordSearch.matches(query, fields: [$0.name, $0.clientNumber, $0.clientType.label])
        }
    }

    var isFiltered: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resetQuery() {
        query = ""
    }

    func load() async {
        guard state == .idle || state.isFailed else { return }
        state = .loading
        do {
            let snapshot = try await records.loadClients()
            clients = snapshot.clients
            origin = snapshot.origin
            state = clients.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class SaleListViewModel {
    private let records: any SaleProviding
    private(set) var sales: [SaleRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle
    var query = ""

    init(records: any SaleProviding) {
        self.records = records
    }

    var filteredSales: [SaleRecord] {
        sales.filter {
            RecordSearch.matches(
                query,
                fields: [$0.saleNumber, $0.clientName, $0.externalInvoiceNumber, $0.saleType.label, $0.paymentStatusLabel]
            )
        }
    }

    var isFiltered: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resetQuery() {
        query = ""
    }

    func load() async {
        guard state == .idle || state.isFailed else { return }
        state = .loading
        do {
            let snapshot = try await records.loadSales()
            sales = snapshot.sales
            origin = snapshot.origin
            state = sales.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }
}

@Observable
final class InvoiceListViewModel {
    private let records: any InvoiceProviding
    private(set) var invoices: [InvoiceRecord] = []
    private(set) var sales: [SaleRecord] = []
    private(set) var origin: DataOrigin = .mock
    private(set) var state: ResourceLoadState = .idle
    var query = ""

    init(records: any InvoiceProviding) {
        self.records = records
    }

    var filteredInvoices: [InvoiceRecord] {
        invoices.filter {
            RecordSearch.matches(
                query,
                fields: [$0.numberLabel, $0.clientName, $0.saleNumber, $0.status.label, $0.invoiceNumber ?? ""]
            )
        }
    }

    var isFiltered: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resetQuery() {
        query = ""
    }

    func load() async {
        guard state == .idle || state.isFailed else { return }
        state = .loading
        do {
            let snapshot = try await records.loadInvoices()
            invoices = snapshot.invoices
            sales = snapshot.sales
            origin = snapshot.origin
            state = invoices.isEmpty ? .empty : .loaded
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? "The list could not be loaded.")
        }
    }

    func amountPaid(for invoice: InvoiceRecord) -> Decimal {
        sales.first { $0.id == invoice.saleID }?.amountPaid ?? .zero
    }
}
