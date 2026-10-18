//
//  RecordListScaffold.swift
//  ERPLITEIOS
//

import SwiftUI

struct RecordListScaffold<Content: View>: View {
    var title: String
    var explanation: String
    var origin: DataOrigin
    var state: ResourceLoadState
    var retry: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                LoadingStateView(title: "Loading \(title)")
            case .failed(let message):
                ErrorStateView(
                    title: "Could not load \(title)",
                    message: message,
                    retry: retry
                )
            case .empty:
                ContentUnavailableView {
                    Label("No \(title)", systemImage: "tray")
                } description: {
                    Text(explanation)
                }
                .accessibilityIdentifier("list.empty")
            case .loaded:
                List {
                    Section {
                        if origin == .mock {
                            MockDataBanner(
                                message: "Mock samples shaped like ERP Lite records. They were not loaded from the server."
                            )
                        }
                        Text(explanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    content()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
