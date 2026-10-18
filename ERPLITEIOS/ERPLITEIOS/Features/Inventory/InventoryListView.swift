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
            explanation: "Physical units stay InventoryItem rows. SKU stock is a separate quantity catalog. This screen does not receive, adjust, or ship.",
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            if !viewModel.items.isEmpty {
                Section("Physical units") {
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
            }
            if !viewModel.skus.isEmpty {
                Section("SKU stock") {
                    ForEach(viewModel.skus) { sku in
                        NavigationLink {
                            SKUDetailView(product: sku)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sku.name)
                                Text("\(sku.sku) · \(sku.available) available")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
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

struct SKUDetailView: View {
    var product: SKUProductRecord

    var body: some View {
        List {
            LabeledContent("SKU", value: product.sku)
            LabeledContent("Active", value: product.isActive ? "Yes" : "No")
            LabeledContent("On hand", value: "\(product.onHand)")
            LabeledContent("Reserved", value: "\(product.reserved)")
            LabeledContent("Available", value: "\(product.available)")
            Text("Quantities are whole units. Cost, receipts, and shipments stay on the server. This screen does not value stock.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
