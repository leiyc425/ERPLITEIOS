//
//  ClientListView.swift
//  ERPLITEIOS
//

import SwiftUI

struct ClientListView: View {
    @State private var viewModel: ClientListViewModel

    init(records: any ERPReading) {
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
            ForEach(viewModel.clients) { client in
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
            Text("Deletion is blocked on the server when a client has sales, expenses, or a billing profile. This screen does not delete records.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
