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

    @Test func searchAndStatusFilterUnits() async {
        let viewModel = InventoryListViewModel(records: MockERPReader(catalog: .sample))
        await viewModel.load()
        viewModel.unitQuery = "reserved"
        #expect(viewModel.filteredUnits.map(\.inventoryNumber) == ["0002"])
        viewModel.unitQuery = ""
        viewModel.unitStatus = .sold
        #expect(viewModel.filteredUnits.map(\.inventoryNumber) == ["0003"])
        viewModel.skuAvailability = .available
        #expect(viewModel.filteredSKUs.map(\.sku) == ["SAMPLE-SKU"])
        #expect(viewModel.filteredSKUs.first?.available == 6)
    }

    @Test func sampleClientShowsABillingProfile() {
        let company = ERPCatalog.sample.clients.first { $0.clientNumber == "0001" }
        #expect(company?.billingProfile?.isActive == true)
        #expect(company?.billingProfile?.isDefault == true)
        #expect(company?.billingProfile?.legalBillingName == "Sample Company")
        let person = ERPCatalog.sample.clients.first { $0.clientNumber == "0002" }
        #expect(person?.billingProfile == nil)
    }
}

@MainActor
struct ConnectionSettingsTests {
    @Test func savedURLIsUsedForHealthAndDoesNotIntegrateTheContract() {
        let store = MemoryEndpointStore()
        let settings = ConnectionSettings(bundled: .mockDefault, store: store)
        settings.draft = "https://example.com/erp"
        settings.saveDraft()
        #expect(settings.effectiveBaseURL == URL(string: "https://example.com/erp"))
        #expect(store.load() == "https://example.com/erp")
        #expect(settings.bundled.contractIntegrated == false)

        settings.draft = "http://user:secret@example.com"
        settings.saveDraft()
        #expect(settings.overrideURL == URL(string: "https://example.com/erp"))
        #expect(settings.validationMessage != nil)
        #expect(!store.load().contains("secret"))
    }

    @Test func dashboardUsesIssuedBalancesOnly() async {
        let viewModel = DashboardViewModel(
            session: Session(accountLabel: "Ada", expiresAt: nil, isMock: true),
            configuration: .mockDefault,
            records: MockERPReader(catalog: .sample)
        )
        await viewModel.load()
        #expect(viewModel.state == .loaded)
        #expect(viewModel.issuedBalanceDue == Decimal(string: "45.20"))
        #expect(viewModel.skuAvailable == 6)
        #expect(viewModel.configuration.contractIntegrated == false)
    }
}
