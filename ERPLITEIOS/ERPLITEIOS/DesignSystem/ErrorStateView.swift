//
//  ErrorStateView.swift
//  ERPLITEIOS
//

import SwiftUI

struct ErrorStateView: View {
    var title: String
    var message: String
    var retry: () -> Void
    var secondaryTitle: String?
    var secondary: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("error.retry")
            if let secondaryTitle, let secondary {
                Button(secondaryTitle, action: secondary)
                    .accessibilityIdentifier("error.secondary")
            }
        }
        .accessibilityIdentifier("error.root")
    }
}
