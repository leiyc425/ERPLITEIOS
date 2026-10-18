//
//  MockERPReader.swift
//  ERPLITEIOS
//

import Foundation

protocol ERPReading {
    func loadCatalog() async throws -> ERPCatalog
}

struct CatalogFailure: Error, Equatable, LocalizedError {
    var message: String

    var errorDescription: String? { message }
}

struct MockERPReader: ERPReading {
    var catalog: ERPCatalog
    var failure: CatalogFailure?

    func loadCatalog() async throws -> ERPCatalog {
        if let failure {
            throw failure
        }
        return catalog
    }
}

extension ERPCatalog {
    static let empty = ERPCatalog(inventory: [], clients: [], sales: [], origin: .mock)

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
        clients: [
            ClientRecord(
                id: 1,
                clientNumber: "0001",
                clientType: .company,
                name: "Sample Company",
                notes: "",
                isActive: true
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
                ]
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
        ],
        origin: .mock
    )
}
