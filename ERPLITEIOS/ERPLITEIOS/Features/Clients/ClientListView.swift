//
//  ClientListView.swift
//  ERPLITEIOS
//

import SwiftUI

struct ClientListView: View {
    @State private var viewModel: ClientListViewModel

    init(records: any ClientProviding) {
        _viewModel = State(initialValue: ClientListViewModel(records: records))
    }

    var body: some View {
        RecordListScaffold(
            title: "Clients",
            explanation: "Customers in this ERP are Client records. There is no separate Customer table.",
            origin: viewModel.origin,
            state: viewModel.state,
            retry: { Task { await viewModel.load() } }
        ) {
            TextField("Search clients", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search clients")
                .accessibilityIdentifier("clients.search")
            if viewModel.filteredClients.isEmpty {
                Text("No clients match this search.")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.filteredClients) { client in
                NavigationLink {
                    ClientDetailView(client: client)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.name)
                        Text("\(client.clientNumber) · \(client.clientType.label)\(client.isActive ? "" : " · Inactive")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("clients.list")
        .task { await viewModel.load() }
    }
}

struct ClientDetailView: View {
    var client: ClientRecord

    var body: some View {
        List {
            LabeledContent("Client number", value: client.clientNumber)
            LabeledContent("Type", value: client.clientType.label)
            LabeledContent("Active", value: client.isActive ? "Yes" : "No")
            if !client.notes.isEmpty {
                Text(client.notes)
            }
            Section("Billing profile") {
                if let profile = client.billingProfile {
                    LabeledContent("Legal billing name", value: profile.legalBillingName)
                    LabeledContent("Default", value: profile.isDefault ? "Yes" : "No")
                    LabeledContent("Active", value: profile.isActive ? "Yes" : "No")
                    if !profile.contactName.isEmpty {
                        LabeledContent("Contact", value: profile.contactName)
                    }
                    if !profile.billingEmail.isEmpty {
                        LabeledContent("Email", value: profile.billingEmail)
                    }
                    if !profile.billingPhone.isEmpty {
                        LabeledContent("Phone", value: profile.billingPhone)
                    }
                    if !profile.addressLine1.isEmpty {
                        LabeledContent("Address", value: "\(profile.addressLine1), \(profile.city) \(profile.regionCode) \(profile.postalCode)")
                    }
                } else {
                    Text("No billing profile is on this sample.")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Creating, editing, and deleting stay on the server. A billing profile also blocks client deletion there.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
