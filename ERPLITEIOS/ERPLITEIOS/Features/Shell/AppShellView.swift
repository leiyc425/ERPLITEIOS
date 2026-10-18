//
//  AppShellView.swift
//  ERPLITEIOS
//

import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case inventory
    case sales
    case invoices
    case clients
    case settings

    init(moduleID: String) {
        switch moduleID {
        case "inventory": self = .inventory
        case "sales": self = .sales
        case "invoices": self = .invoices
        case "clients": self = .clients
        default: self = .dashboard
        }
    }
}

struct AppShellView: View {
    var session: Session
    var dependencies: AppDependencies
    var signOut: () async -> Void
    @State private var tab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DashboardView(
                    tab: $tab,
                    session: session,
                    dependencies: dependencies,
                    signOut: signOut
                )
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            .tag(AppTab.dashboard)

            NavigationStack {
                InventoryListView(records: dependencies.records)
            }
            .tabItem { Label("Inventory", systemImage: "shippingbox") }
            .tag(AppTab.inventory)

            NavigationStack {
                SaleListView(records: dependencies.records)
            }
            .tabItem { Label("Sales", systemImage: "cart") }
            .tag(AppTab.sales)

            NavigationStack {
                InvoiceListView(records: dependencies.records)
            }
            .tabItem { Label("Invoices", systemImage: "doc.text") }
            .tag(AppTab.invoices)

            NavigationStack {
                ClientListView(records: dependencies.records)
            }
            .tabItem { Label("Clients", systemImage: "person.2") }
            .tag(AppTab.clients)

            NavigationStack {
                SettingsView(dependencies: dependencies, signOut: signOut)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .accessibilityIdentifier("app.tabs")
    }
}
