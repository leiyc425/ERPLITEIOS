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

        let skuSale = try #require(catalog.sales.first { $0.saleNumber == "0004" })
        let skuLine = try #require(skuSale.lines.first)
        #expect(skuLine.skuProductID != nil)
        #expect(skuLine.inventoryItemID == nil)
        #expect(skuLine.fulfillment == .partiallyDelivered)
        #expect(skuSale.fulfillment == .partiallyDelivered)
        #expect(skuSale.total == Decimal(string: "40.00"))
        #expect(skuSale.amountDue == Decimal(string: "45.20"))
        #expect(skuSale.outstandingBalance == Decimal(string: "45.20"))
        #expect(skuSale.paymentStatus == .unpaid)
    }

    @Test func sampleInvoicesFollowFrozenTotals() throws {
        let catalog = ERPCatalog.sample
        #expect(catalog.invoices.allSatisfy { Money.cad($0.subtotal + $0.taxTotal) == $0.grandTotal })

        let draft = try #require(catalog.invoices.first { $0.status == .draft })
        #expect(draft.invoiceNumber == nil)
        #expect(draft.balanceDue(amountPaidOnSale: 10) == nil)

        let issued = try #require(catalog.invoices.first { $0.invoiceNumber == "FM-2601001" })
        #expect(issued.balanceDue(amountPaidOnSale: Decimal(string: "40.00") ?? 40) == .zero)

        let voided = try #require(catalog.invoices.first { $0.status == .void })
        let voidedSale = try #require(catalog.sales.first { $0.id == voided.saleID })
        #expect(voidedSale.issuedInvoiceGrandTotal == nil)
        #expect(voidedSale.amountDue == voidedSale.total)

        let sku = try #require(catalog.skus.first)
        #expect(sku.available == 6)
        #expect(sku.reserved == 2)
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
