//
//  SaleListView.swift
//  ERPLITEIOS
//

import SwiftUI

enum SaleListPurpose: Equatable {
    case sales
    case invoices

    var title: String {
        switch self {
        case .sales: "Sales"
        case .invoices: "Invoices"
        }
    }

    var explanation: String {
        switch self {
        case .sales:
            "ERP Lite has no separate order model. A Sale is the business transaction."
        case .invoices:
            "A Sale is the invoice header. This list is the same Sale records, not a second document type."
        }
    }

    var identifier: String {
        switch self {
        case .sales: "sales.list"
        case .invoices: "invoices.list"
        }
    }
}

struct SaleListView: View {
    @State private var viewModel: SaleListViewModel
    private let purpose: SaleListPurpose

    init(records: any ERPReading, purpose: SaleListPurpose) {
        self.purpose = purpose
        _viewModel = State(initialValue: SaleListViewModel(records: records))
    }

    var body: some View {
        RecordListScaffold(
            title: purpose.title,
            explanation: purpose.explanation,
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            ForEach(viewModel.sales) { sale in
                NavigationLink {
                    SaleDetailView(sale: sale, purpose: purpose)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rowTitle(sale))
                        Text(rowDetail(sale))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier(purpose.identifier)
        .task { await viewModel.load() }
    }

    private func rowTitle(_ sale: SaleRecord) -> String {
        switch purpose {
        case .sales:
            return "\(sale.saleNumber) · \(sale.clientName)"
        case .invoices:
            return "\(sale.saleNumber) · \(sale.invoiceLabel)"
        }
    }

    private func rowDetail(_ sale: SaleRecord) -> String {
        switch purpose {
        case .sales:
            return "\(sale.saleDate) · \(sale.fulfillment.label) · \(sale.saleType.label)"
        case .invoices:
            return "\(sale.clientName) · \(sale.paymentStatusLabel) · \(Money.label(sale.outstandingBalance)) outstanding"
        }
    }
}

struct SaleDetailView: View {
    var sale: SaleRecord
    var purpose: SaleListPurpose

    var body: some View {
        List {
            LabeledContent("Sale number", value: sale.saleNumber)
            LabeledContent("External invoice", value: sale.invoiceLabel)
            LabeledContent("Client", value: sale.clientName)
            LabeledContent("Sale date", value: sale.saleDate)
            LabeledContent("Type", value: sale.saleType.label)
            LabeledContent("Fulfillment", value: sale.fulfillment.label)
            LabeledContent("Payment", value: sale.paymentStatusLabel)
            LabeledContent("Total", value: Money.label(sale.total))
            LabeledContent("Paid", value: Money.label(sale.amountPaid))
            LabeledContent("Outstanding", value: Money.label(sale.outstandingBalance))

            Section("Lines") {
                ForEach(sale.lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(line.lineNumber). \(line.name)")
                        Text("\(line.lineType.label) · qty \(line.quantity) · \(line.fulfillmentStatus.label) · \(Money.label(line.lineTotal))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if purpose == .invoices {
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
            }

            Text("Creating, editing, fulfilling, and deleting stay on the server. This screen is read-only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(sale.saleNumber)
        .navigationBarTitleDisplayMode(.inline)
    }
}
