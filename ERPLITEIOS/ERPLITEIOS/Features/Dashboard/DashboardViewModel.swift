//
//  DashboardViewModel.swift
//  ERPLITEIOS
//

import Foundation

struct DashboardModule: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var origin: DataOrigin
}

/// Formats the shell. It does not invent ERP Lite records.
struct DashboardViewModel {
    var session: Session
    var configuration: AppConfiguration

    var showsMockBanner: Bool {
        session.isMock || modules.contains { $0.origin == .mock }
    }

    var accountLine: String {
        if session.isMock {
            return "\(session.accountLabel) · mock session"
        }
        return "\(session.accountLabel) · backend session"
    }

    var backendTitle: String {
        if configuration.baseURL == nil {
            return "Backend URL not set"
        }
        return "Base URL configured"
    }

    var backendDetail: String {
        if let baseURL = configuration.baseURL {
            return "\(baseURL.absoluteString) is saved for a future contract. This build does not call it."
        }
        return "Set ERPLITE_API_BASE_URL when an ERP Lite HTTP contract exists. No request is sent until then."
    }

    var modules: [DashboardModule] {
        [
            DashboardModule(
                id: "inventory",
                title: "Inventory",
                detail: "Mock placeholder. Not loaded from ERP Lite.",
                origin: .mock
            ),
            DashboardModule(
                id: "orders",
                title: "Orders",
                detail: "Mock placeholder. Not loaded from ERP Lite.",
                origin: .mock
            ),
            DashboardModule(
                id: "customers",
                title: "Customers",
                detail: "Mock placeholder. Not loaded from ERP Lite.",
                origin: .mock
            ),
        ]
    }
}
