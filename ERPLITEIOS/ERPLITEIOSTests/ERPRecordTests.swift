import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct ERPRecordTests {
    @Test func classificationMatchesTheDjangoPrefixes() {
        #expect(SaleClassification.saleType(forExternalInvoiceNumber: "PRG001") == .program)
        #expect(SaleClassification.saleType(forExternalInvoiceNumber: " sh004 ") == .secondhand)
        #expect(SaleClassification.saleType(forExternalInvoiceNumber: "") == .other)
        #expect(SaleClassification.saleType(forExternalInvoiceNumber: "INV-9") == .other)
    }

    @Test func sampleSalesFollowServerDerivedRules() throws {
        let catalog = ERPCatalog.sample
        let paid = try #require(catalog.sales.first { $0.saleNumber == "0001" })
        #expect(paid.saleType == .secondhand)
        #expect(paid.total == Decimal(string: "40.00"))
        #expect(paid.paymentStatus == .paid)
        #expect(paid.fulfillment == .delivered)
        #expect(paid.outstandingBalance == .zero)

        let program = try #require(catalog.sales.first { $0.saleNumber == "0002" })
        #expect(program.saleType == .program)
        #expect(program.total == Decimal(string: "30.00"))
        #expect(program.paymentStatus == .unpaid)
        #expect(program.fulfillment == .notDelivered)
        #expect(program.lines.allSatisfy { $0.inventoryItemID == nil })

        let partial = try #require(catalog.sales.first { $0.saleNumber == "0003" })
        #expect(partial.saleType == .other)
        #expect(partial.paymentStatus == .partiallyPaid)
        #expect(partial.fulfillment == .partiallyDelivered)
        #expect(partial.outstandingBalance == Decimal(string: "15.00"))
        #expect(partial.paymentStatusLabel == "Partially Paid")
    }

    @Test func linkedInventoryLinesStayAtQuantityOne() {
        let catalog = ERPCatalog.sample
        let linked = catalog.sales.flatMap(\.lines).filter { $0.inventoryItemID != nil }
        #expect(linked.allSatisfy { $0.quantity == 1 && $0.lineType == .product })
        #expect(catalog.origin == .mock)
    }

    @Test func zeroTotalSaleHasNoBalanceDue() {
        let sale = SaleRecord(
            id: 9,
            saleNumber: "0009",
            externalInvoiceNumber: "",
            clientName: "Sample Company",
            saleDate: "2026-03-01",
            lines: [],
            payments: []
        )
        #expect(sale.total == .zero)
        #expect(sale.paymentStatus == .paid)
        #expect(sale.paymentStatusLabel == "No Balance Due")
        #expect(sale.fulfillment == .notDelivered)
    }
}

@MainActor
struct CatalogListViewModelTests {
    @Test func emptyCatalogShowsTheEmptyState() async {
        let viewModel = ClientListViewModel(records: MockERPReader(catalog: .empty))
        await viewModel.load()
        #expect(viewModel.state == .empty)
        #expect(viewModel.clients.isEmpty)
    }

    @Test func failureSurfacesAMessage() async {
        let viewModel = InventoryListViewModel(
            records: MockERPReader(catalog: .empty, failure: CatalogFailure(message: "Sample failure"))
        )
        await viewModel.load()
        #expect(viewModel.state == .failed("Sample failure"))
    }

    @Test func sampleInventoryLoads() async {
        let viewModel = InventoryListViewModel(records: MockERPReader(catalog: .sample))
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.origin == .mock)
        #expect(viewModel.items.contains { $0.name == "Sample physical unit" })
    }
}
