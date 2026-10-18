//
//  LoadingStateView.swift
//  ERPLITEIOS
//

import SwiftUI

struct LoadingStateView: View {
    var title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier("loading.root")
    }
}
