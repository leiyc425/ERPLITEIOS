//
//  InventoryListView.swift
//  ERPLITEIOS
//

import SwiftUI

struct InventoryListView: View {
    @State private var viewModel: InventoryListViewModel

    init(records: any ERPReading) {
        _viewModel = State(initialValue: InventoryListViewModel(records: records))
    }

    var body: some View {
        RecordListScaffold(
            title: "Inventory",
            explanation: "Each row is one physical unit (InventoryItem). ERP Lite does not have a shared SKU catalog.",
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            ForEach(viewModel.items) { item in
                NavigationLink {
                    InventoryDetailView(item: item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                        Text("\(item.inventoryNumber) · \(item.status.label)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("inventory.list")
        .task { await viewModel.load() }
    }
}

struct InventoryDetailView: View {
    var item: InventoryItemRecord

    var body: some View {
        List {
            LabeledContent("Inventory number", value: item.inventoryNumber)
            LabeledContent("Status", value: item.status.label)
            LabeledContent("Acquired", value: item.acquiredDate)
            LabeledContent("Purchase cost", value: Money.label(item.purchaseCost))
            if !item.externalInventoryNumber.isEmpty {
                LabeledContent("External number", value: item.externalInventoryNumber)
            }
            if let vendorName = item.vendorName {
                LabeledContent("Vendor", value: vendorName)
            }
            if !item.purchaseSource.isEmpty {
                LabeledContent("Purchase source", value: item.purchaseSource)
            }
            if !item.specification.isEmpty {
                Text(item.specification)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
