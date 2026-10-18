//
//  ERPRecords.swift
//  ERPLITEIOS
//
//  Field names follow the Django models inspected in ERPLITE at f75a051.
//  These types are not a claim that a JSON API returns them.

import Foundation

enum InventoryStatus: String, Equatable, CaseIterable {
    case inStock = "IN_STOCK"
    case reserved = "RESERVED"
    case sold = "SOLD"

    var label: String {
        switch self {
        case .inStock: "In Stock"
        case .reserved: "Reserved"
        case .sold: "Sold"
        }
    }
}

enum ClientType: String, Equatable {
    case company = "COMPANY"
    case individual = "INDIVIDUAL"

    var label: String {
        switch self {
        case .company: "Company"
        case .individual: "Individual"
        }
    }
}

enum SaleType: String, Equatable {
    case program = "PROGRAM"
    case secondhand = "SECONDHAND"
    case other = "OTHER"

    var label: String {
        switch self {
        case .program: "Program"
        case .secondhand: "Secondhand Sale"
        case .other: "Other / Unclassified"
        }
    }
}

enum SaleLineType: String, Equatable {
    case product = "PRODUCT"
    case service = "SERVICE"

    var label: String {
        switch self {
        case .product: "Product"
        case .service: "Service"
        }
    }
}

enum LineFulfillment: String, Equatable {
    case notDelivered = "NOT_DELIVERED"
    case delivered = "DELIVERED"

    var label: String {
        switch self {
        case .notDelivered: "Not Delivered"
        case .delivered: "Delivered"
        }
    }
}

enum SaleFulfillment: String, Equatable {
    case notDelivered = "NOT_DELIVERED"
    case partiallyDelivered = "PARTIALLY_DELIVERED"
    case delivered = "DELIVERED"

    var label: String {
        switch self {
        case .notDelivered: "Not Delivered"
        case .partiallyDelivered: "Partially Delivered"
        case .delivered: "Delivered"
        }
    }
}

enum PaymentStatus: String, Equatable {
    case unpaid = "UNPAID"
    case partiallyPaid = "PARTIALLY_PAID"
    case paid = "PAID"

    var label: String {
        switch self {
        case .unpaid: "Unpaid"
        case .partiallyPaid: "Partially Paid"
        case .paid: "Paid"
        }
    }
}

struct InventoryItemRecord: Identifiable, Equatable {
    var id: Int
    var inventoryNumber: String
    var externalInventoryNumber: String
    var name: String
    var specification: String
    var acquiredDate: String
    var purchaseCost: Decimal
    var status: InventoryStatus
    var purchaseSource: String
    var vendorName: String?
    var notes: String
}

struct ClientRecord: Identifiable, Equatable {
    var id: Int
    var clientNumber: String
    var clientType: ClientType
    var name: String
    var notes: String
    var isActive: Bool
}

struct PaymentRecord: Identifiable, Equatable {
    var id: Int
    var paymentDate: String
    var amount: Decimal
    var originalCurrency: String
    var originalAmount: Decimal
}

struct SaleLineRecord: Identifiable, Equatable {
    var id: Int
    var lineNumber: Int
    var lineType: SaleLineType
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var inventoryItemID: Int?
    var fulfillmentStatus: LineFulfillment

    var lineTotal: Decimal {
        Money.cad(Decimal(quantity) * unitPrice)
    }
}

struct SaleRecord: Identifiable, Equatable {
    var id: Int
    var saleNumber: String
    var externalInvoiceNumber: String
    var clientName: String
    var saleDate: String
    var lines: [SaleLineRecord]
    var payments: [PaymentRecord]

    var saleType: SaleType {
        SaleClassification.saleType(forExternalInvoiceNumber: externalInvoiceNumber)
    }

    var total: Decimal {
        Money.cad(lines.reduce(Decimal.zero) { $0 + $1.lineTotal })
    }

    var amountPaid: Decimal {
        Money.cad(payments.reduce(Decimal.zero) { $0 + $1.amount })
    }

    var outstandingBalance: Decimal {
        Money.cad(total - amountPaid)
    }

    var fulfillment: SaleFulfillment {
        if lines.isEmpty {
            return .notDelivered
        }
        let delivered = lines.filter { $0.fulfillmentStatus == .delivered }.count
        if delivered == 0 {
            return .notDelivered
        }
        if delivered == lines.count {
            return .delivered
        }
        return .partiallyDelivered
    }

    var paymentStatus: PaymentStatus {
        if total <= .zero {
            return .paid
        }
        if amountPaid <= .zero {
            return .unpaid
        }
        if amountPaid < total {
            return .partiallyPaid
        }
        return .paid
    }

    var paymentStatusLabel: String {
        if total <= .zero {
            return "No Balance Due"
        }
        return paymentStatus.label
    }

    var invoiceLabel: String {
        if externalInvoiceNumber.isEmpty {
            return "No external invoice number"
        }
        return externalInvoiceNumber
    }
}

enum SaleClassification {
    /// Matches `sales/classification.py` `classify_external_invoice_number`.
    static func saleType(forExternalInvoiceNumber value: String) -> SaleType {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if text.hasPrefix("PRG") {
            return .program
        }
        if text.hasPrefix("SH") {
            return .secondhand
        }
        return .other
    }
}

enum Money {
    static func cad(_ value: Decimal) -> Decimal {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .bankers)
        return rounded
    }

    static func label(_ value: Decimal) -> String {
        let rounded = cad(value)
        return "CAD \(rounded.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_CA"))))"
    }
}

struct ERPCatalog: Equatable {
    var inventory: [InventoryItemRecord]
    var clients: [ClientRecord]
    var sales: [SaleRecord]
    var origin: DataOrigin
}

struct HealthStatus: Decodable, Equatable {
    var status: String
    var database: String
}

struct HealthReport: Equatable {
    var status: HealthStatus
    var origin: DataOrigin
}
