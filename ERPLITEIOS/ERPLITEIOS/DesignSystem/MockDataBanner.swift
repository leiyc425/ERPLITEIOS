//
//  MockDataBanner.swift
//  ERPLITEIOS
//

import SwiftUI

struct MockDataBanner: View {
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("MOCK")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.mockForeground.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.mockForeground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.mockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mock-data-banner")
    }
}
