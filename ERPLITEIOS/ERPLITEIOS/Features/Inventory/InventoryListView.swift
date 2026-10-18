//
//  InventoryListView.swift
//  ERPLITEIOS
//

import SwiftUI

struct InventoryListView: View {
    @State private var viewModel: InventoryListViewModel

    init(records: any InventoryProviding) {
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
            Section("Physical units") {
                TextField("Search units", text: $viewModel.unitQuery)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Search physical units")
                    .accessibilityIdentifier("inventory.unitSearch")
                Picker("Status", selection: $viewModel.unitStatus) {
                    ForEach(UnitStatusFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .accessibilityIdentifier("inventory.unitStatus")
                Picker("Sort", selection: $viewModel.unitSort) {
                    ForEach(UnitSort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
                if viewModel.filteredUnits.isEmpty {
                    Text("No physical units match this search.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.filteredUnits) { item in
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
            Section("SKU stock") {
                TextField("Search SKUs", text: $viewModel.skuQuery)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Search SKU stock")
                    .accessibilityIdentifier("inventory.skuSearch")
                Picker("Availability", selection: $viewModel.skuAvailability) {
                    ForEach(SKUAvailabilityFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .accessibilityIdentifier("inventory.skuAvailability")
                Picker("Sort SKUs", selection: $viewModel.skuSort) {
                    ForEach(SKUSort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
                if viewModel.filteredSKUs.isEmpty {
                    Text("No SKUs match this search.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.filteredSKUs) { sku in
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
