//
//  SaleListView.swift
//  ERPLITEIOS
//

import SwiftUI

struct SaleListView: View {
    @State private var viewModel: SaleListViewModel

    init(records: any SaleProviding) {
        _viewModel = State(initialValue: SaleListViewModel(records: records))
    }

    var body: some View {
        RecordListScaffold(
            title: "Sales",
            explanation: "A Sale is the business transaction. There is no separate order. Billing invoices are a different record.",
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            TextField("Search sales", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search sales")
                .accessibilityIdentifier("sales.search")
            if viewModel.filteredSales.isEmpty {
                Text("No sales match this search.")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.filteredSales) { sale in
                NavigationLink {
                    SaleDetailView(sale: sale)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(sale.saleNumber) · \(sale.clientName)")
                        Text("\(sale.saleDate) · \(sale.fulfillment.label) · \(sale.saleType.label)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("sales.list")
        .task { await viewModel.load() }
    }
}

struct SaleDetailView: View {
    var sale: SaleRecord

    var body: some View {
        List {
            LabeledContent("Sale number", value: sale.saleNumber)
            LabeledContent("External reference", value: sale.invoiceLabel)
            LabeledContent("Client", value: sale.clientName)
            LabeledContent("Sale date", value: sale.saleDate)
            LabeledContent("Type", value: sale.saleType.label)
            LabeledContent("Fulfillment", value: sale.fulfillment.label)
            LabeledContent("Payment", value: sale.paymentStatusLabel)
            LabeledContent("Sale total", value: Money.label(sale.total))
            LabeledContent("Amount due", value: Money.label(sale.amountDue))
            LabeledContent("Paid", value: Money.label(sale.amountPaid))
            LabeledContent("Outstanding", value: Money.label(sale.outstandingBalance))

            Section("Lines") {
                ForEach(sale.lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(line.lineNumber). \(line.name)")
                        Text(lineDetail(line))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Payments") {
                if sale.payments.isEmpty {
                    Text("No payments on this sample.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sale.payments) { payment in
                        LabeledContent(payment.paymentDate, value: Money.label(payment.amount))
                    }
                }
            }

            Text("The external reference classifies the sale. It is not the billing invoice number. Creating, editing, shipping, and paying stay on the server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(sale.saleNumber)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lineDetail(_ line: SaleLineRecord) -> String {
        var text = "\(line.lineType.label) · qty \(line.quantity) · \(line.fulfillment.label) · \(Money.label(line.lineTotal))"
        if line.skuProductID != nil {
            text += " · shipped \(line.shippedQuantity) · cancelled \(line.cancelledQuantity)"
        }
        return text
    }
}

struct InvoiceListView: View {
    @State private var viewModel: InvoiceListViewModel

    init(records: any InvoiceProviding) {
        _viewModel = State(initialValue: InvoiceListViewModel(records: records))
    }

    var body: some View {
        RecordListScaffold(
            title: "Invoices",
            explanation: "An invoice belongs to one sale. Drafts have no number. Issued and void invoices keep their FM number. Totals shown here are stored samples, not calculated on the device.",
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            TextField("Search invoices", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search invoices")
                .accessibilityIdentifier("invoices.search")
            if viewModel.filteredInvoices.isEmpty {
                Text("No invoices match this search.")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.filteredInvoices) { invoice in
                NavigationLink {
                    InvoiceDetailView(
                        invoice: invoice,
                        amountPaidOnSale: viewModel.amountPaid(for: invoice)
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(invoice.numberLabel) · \(invoice.clientName)")
                        Text("\(invoice.status.label) · sale \(invoice.saleNumber) · \(Money.label(invoice.grandTotal))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("invoices.list")
        .task { await viewModel.load() }
    }
}

struct InvoiceDetailView: View {
    var invoice: InvoiceRecord
    var amountPaidOnSale: Decimal

    var body: some View {
        List {
            LabeledContent("Status", value: invoice.status.label)
            LabeledContent("Invoice number", value: invoice.numberLabel)
            LabeledContent("Sale", value: invoice.saleNumber)
            LabeledContent("Client", value: invoice.clientName)
            LabeledContent("Issuer", value: invoice.issuerLegalName)
            if let issueDate = invoice.issueDate {
                LabeledContent("Issue date", value: issueDate)
            }
            LabeledContent("Subtotal", value: Money.label(invoice.subtotal))
            LabeledContent("Tax", value: Money.label(invoice.taxTotal))
            LabeledContent("Grand total", value: Money.label(invoice.grandTotal))
            if let balance = invoice.balanceDue(amountPaidOnSale: amountPaidOnSale) {
                LabeledContent("Sale payments", value: Money.label(amountPaidOnSale))
                LabeledContent("Balance due", value: Money.label(balance))
            }

            if !invoice.lines.isEmpty {
                Section("Lines") {
                    ForEach(invoice.lines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(line.lineNumber). \(line.name)")
                            Text(lineCaption(line))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text("Payments stay on the sale. A void is not a refund. Issuing, voiding, and PDF download stay on the server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(invoice.numberLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lineCaption(_ line: InvoiceLineRecord) -> String {
        var text = "qty \(line.quantity) · net \(Money.label(line.lineNet)) · tax \(Money.label(line.taxTotal))"
        if !line.sourceSKUCode.isEmpty {
            text += " · \(line.sourceSKUCode)"
        }
        return text
    }
}
