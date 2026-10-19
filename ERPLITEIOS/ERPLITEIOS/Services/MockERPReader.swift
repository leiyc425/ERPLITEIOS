//
//  MockERPReader.swift
//  ERPLITEIOS
//

import Foundation

protocol ERPReading {
    func loadCatalog() async throws -> ERPCatalog
}

protocol DashboardProviding {
    func loadDashboard() async throws -> ERPCatalog
}

struct InventorySnapshot: Equatable {
    var units: [InventoryItemRecord]
    var skus: [SKUProductRecord]
    var origin: DataOrigin
}

protocol InventoryProviding {
    func loadInventory() async throws -> InventorySnapshot
}

struct ClientSnapshot: Equatable {
    var clients: [ClientRecord]
    var origin: DataOrigin
}

protocol ClientProviding {
    func loadClients() async throws -> ClientSnapshot
}

struct SaleSnapshot: Equatable {
    var sales: [SaleRecord]
    var origin: DataOrigin
}

protocol SaleProviding {
    func loadSales() async throws -> SaleSnapshot
}

struct InvoiceSnapshot: Equatable {
    var invoices: [InvoiceRecord]
    var sales: [SaleRecord]
    var origin: DataOrigin
}

protocol InvoiceProviding {
    func loadInvoices() async throws -> InvoiceSnapshot
}

protocol ERPProviding: ERPReading, DashboardProviding, InventoryProviding, ClientProviding, SaleProviding, InvoiceProviding {}

struct CatalogFailure: Error, Equatable, LocalizedError {
    var message: String

    var errorDescription: String? { message }
}

struct MockERPReader: ERPProviding {
    /// Sample records stay in the process that built them. They are not written to the read cache or to disk.
    static let cachePolicy = ReadCachePolicy.bypass

    var catalog: ERPCatalog
    var failure: CatalogFailure?

    func loadCatalog() async throws -> ERPCatalog {
        if let failure {
            throw failure
        }
        return catalog
    }

    func loadDashboard() async throws -> ERPCatalog {
        try await loadCatalog()
    }

    func loadInventory() async throws -> InventorySnapshot {
        let catalog = try await loadCatalog()
        return InventorySnapshot(units: catalog.inventory, skus: catalog.skus, origin: catalog.origin)
    }

    func loadClients() async throws -> ClientSnapshot {
        let catalog = try await loadCatalog()
        return ClientSnapshot(clients: catalog.clients, origin: catalog.origin)
    }

    func loadSales() async throws -> SaleSnapshot {
        let catalog = try await loadCatalog()
        return SaleSnapshot(sales: catalog.sales, origin: catalog.origin)
    }

    func loadInvoices() async throws -> InvoiceSnapshot {
        let catalog = try await loadCatalog()
        return InvoiceSnapshot(invoices: catalog.invoices, sales: catalog.sales, origin: catalog.origin)
    }
}

extension ERPCatalog {
    static let empty = ERPCatalog(inventory: [], skus: [], clients: [], sales: [], invoices: [], origin: .mock)

    /// Obvious samples. Counts and balances are derived from these rows, not from the server.
    static let sample = ERPCatalog(
        inventory: [
            InventoryItemRecord(
                id: 1,
                inventoryNumber: "0001",
                externalInventoryNumber: "",
                name: "Sample physical unit",
                specification: "Sample specification",
                acquiredDate: "2026-01-02",
                purchaseCost: Decimal(string: "10.00") ?? 10,
                status: .inStock,
                purchaseSource: "Sample channel",
                vendorName: "Sample Vendor",
                notes: ""
            ),
            InventoryItemRecord(
                id: 2,
                inventoryNumber: "0002",
                externalInventoryNumber: "",
                name: "Sample reserved unit",
                specification: "",
                acquiredDate: "2026-01-03",
                purchaseCost: Decimal.zero,
                status: .reserved,
                purchaseSource: "",
                vendorName: nil,
                notes: ""
            ),
            InventoryItemRecord(
                id: 3,
                inventoryNumber: "0003",
                externalInventoryNumber: "LEGACY-3",
                name: "Sample sold unit",
                specification: "",
                acquiredDate: "2026-01-04",
                purchaseCost: Decimal(string: "25.50") ?? 25.5,
                status: .sold,
                purchaseSource: "",
                vendorName: "Sample Vendor",
                notes: ""
            ),
        ],
        skus: [
            SKUProductRecord(
                id: 1,
                sku: "SAMPLE-SKU",
                name: "Sample quantity product",
                isActive: true,
                onHand: 8,
                reserved: 2
            ),
            SKUProductRecord(
                id: 2,
                sku: "SHARED-CODE",
                name: "Shared code product",
                isActive: true,
                onHand: 0,
                reserved: 0
            ),
        ],
        assets: [
            AssetRecord(
                id: 1,
                assetNumber: "A-0001",
                name: "Sample laptop",
                assetType: "LAPTOP",
                status: "IN_USE"
            ),
            AssetRecord(
                id: 2,
                assetNumber: "SHARED-CODE",
                name: "Shared code asset",
                assetType: "OTHER",
                status: "IDLE"
            ),
        ],
        clients: [
            ClientRecord(
                id: 1,
                clientNumber: "0001",
                clientType: .company,
                name: "Sample Company",
                notes: "",
                isActive: true,
                billingProfile: ClientBillingProfileRecord(
                    legalBillingName: "Sample Company",
                    contactName: "Sample Contact",
                    billingEmail: "billing@example.com",
                    billingPhone: "613-555-0100",
                    addressLine1: "1 Sample Street",
                    city: "Ottawa",
                    regionCode: "ON",
                    postalCode: "K1A 0B1",
                    countryCode: "CA",
                    isDefault: true,
                    isActive: true
                )
            ),
            ClientRecord(
                id: 2,
                clientNumber: "0002",
                clientType: .individual,
                name: "Sample Person",
                notes: "",
                isActive: false
            ),
        ],
        sales: [
            SaleRecord(
                id: 1,
                saleNumber: "0001",
                externalInvoiceNumber: "SH004",
                clientName: "Sample Company",
                saleDate: "2026-01-15",
                lines: [
                    SaleLineRecord(
                        id: 11,
                        lineNumber: 1,
                        lineType: .product,
                        name: "Sample sold unit",
                        quantity: 1,
                        unitPrice: Decimal(string: "40.00") ?? 40,
                        inventoryItemID: 3,
                        fulfillmentStatus: .delivered
                    ),
                ],
                payments: [
                    PaymentRecord(
                        id: 21,
                        paymentDate: "2026-01-20",
                        amount: Decimal(string: "40.00") ?? 40,
                        originalCurrency: "CAD",
                        originalAmount: Decimal(string: "40.00") ?? 40
                    ),
                ],
                issuedInvoiceGrandTotal: Decimal(string: "40.00")
            ),
            SaleRecord(
                id: 2,
                saleNumber: "0002",
                externalInvoiceNumber: "PRG001",
                clientName: "Sample Person",
                saleDate: "2026-02-01",
                lines: [
                    SaleLineRecord(
                        id: 12,
                        lineNumber: 1,
                        lineType: .service,
                        name: "Sample service",
                        quantity: 2,
                        unitPrice: Decimal(string: "15.00") ?? 15,
                        inventoryItemID: nil,
                        fulfillmentStatus: .notDelivered
                    ),
                ],
                payments: []
            ),
            SaleRecord(
                id: 3,
                saleNumber: "0003",
                externalInvoiceNumber: "",
                clientName: "Sample Company",
                saleDate: "2026-02-10",
                lines: [
                    SaleLineRecord(
                        id: 13,
                        lineNumber: 1,
                        lineType: .product,
                        name: "Unlinked sample",
                        quantity: 1,
                        unitPrice: Decimal(string: "10.00") ?? 10,
                        inventoryItemID: nil,
                        fulfillmentStatus: .notDelivered
                    ),
                    SaleLineRecord(
                        id: 14,
                        lineNumber: 2,
                        lineType: .service,
                        name: "Partial sample",
                        quantity: 1,
                        unitPrice: Decimal(string: "10.00") ?? 10,
                        inventoryItemID: nil,
                        fulfillmentStatus: .delivered
                    ),
                ],
                payments: [
                    PaymentRecord(
                        id: 22,
                        paymentDate: "2026-02-11",
                        amount: Decimal(string: "5.00") ?? 5,
                        originalCurrency: "CAD",
                        originalAmount: Decimal(string: "5.00") ?? 5
                    ),
                ]
            ),
            SaleRecord(
                id: 4,
                saleNumber: "0004",
                externalInvoiceNumber: "",
                clientName: "Sample Company",
                saleDate: "2026-03-02",
                lines: [
                    SaleLineRecord(
                        id: 15,
                        lineNumber: 1,
                        lineType: .product,
                        name: "Sample quantity product",
                        quantity: 4,
                        unitPrice: Decimal(string: "10.00") ?? 10,
                        inventoryItemID: nil,
                        skuProductID: 1,
                        fulfillmentStatus: .notDelivered,
                        shippedQuantity: 2,
                        cancelledQuantity: 0
                    ),
                ],
                payments: [],
                issuedInvoiceGrandTotal: Decimal(string: "45.20")
            ),
        ],
        invoices: [
            InvoiceRecord(
                id: 101,
                saleID: 1,
                saleNumber: "0001",
                clientName: "Sample Company",
                status: .issued,
                invoiceNumber: "FM-2601001",
                issueDate: "2026-01-15",
                subtotal: Decimal(string: "40.00") ?? 40,
                taxTotal: .zero,
                grandTotal: Decimal(string: "40.00") ?? 40,
                issuerLegalName: "Sample Issuer",
                lines: [
                    InvoiceLineRecord(
                        id: 201,
                        lineNumber: 1,
                        name: "Sample sold unit",
                        quantity: 1,
                        lineNet: Decimal(string: "40.00") ?? 40,
                        taxTotal: .zero,
                        gross: Decimal(string: "40.00") ?? 40,
                        sourceSKUCode: ""
                    ),
                ]
            ),
            InvoiceRecord(
                id: 102,
                saleID: 2,
                saleNumber: "0002",
                clientName: "Sample Person",
                status: .draft,
                invoiceNumber: nil,
                issueDate: nil,
                subtotal: Decimal(string: "30.00") ?? 30,
                taxTotal: .zero,
                grandTotal: Decimal(string: "30.00") ?? 30,
                issuerLegalName: "Sample Issuer",
                lines: []
            ),
            InvoiceRecord(
                id: 103,
                saleID: 3,
                saleNumber: "0003",
                clientName: "Sample Company",
                status: .void,
                invoiceNumber: "FM-2602001",
                issueDate: "2026-02-10",
                subtotal: Decimal(string: "20.00") ?? 20,
                taxTotal: .zero,
                grandTotal: Decimal(string: "20.00") ?? 20,
                issuerLegalName: "Sample Issuer",
                lines: []
            ),
            InvoiceRecord(
                id: 104,
                saleID: 4,
                saleNumber: "0004",
                clientName: "Sample Company",
                status: .issued,
                invoiceNumber: "FM-2603001",
                issueDate: "2026-03-02",
                subtotal: Decimal(string: "40.00") ?? 40,
                taxTotal: Decimal(string: "5.20") ?? 5.2,
                grandTotal: Decimal(string: "45.20") ?? 45.2,
                issuerLegalName: "Sample Issuer",
                lines: [
                    InvoiceLineRecord(
                        id: 204,
                        lineNumber: 1,
                        name: "Sample quantity product",
                        quantity: 4,
                        lineNet: Decimal(string: "40.00") ?? 40,
                        taxTotal: Decimal(string: "5.20") ?? 5.2,
                        gross: Decimal(string: "45.20") ?? 45.2,
                        sourceSKUCode: "SAMPLE-SKU"
                    ),
                ]
            ),
        ],
        origin: .mock
    )
}
