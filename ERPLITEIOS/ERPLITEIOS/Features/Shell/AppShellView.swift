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

@Observable
final class AppShellState {
    var tab: AppTab = .dashboard
    private(set) var generation: Int = 0

    func reset() {
        tab = .dashboard
        generation += 1
    }
}

struct AppShellView: View {
    var session: Session
    var dependencies: AppDependencies
    var signOut: () async -> Void

    var body: some View {
        TabView(selection: Bindable(dependencies.shell).tab) {
            NavigationStack {
                DashboardView(
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
        .id(dependencies.shell.generation)
        .accessibilityIdentifier("app.tabs")
    }
}
