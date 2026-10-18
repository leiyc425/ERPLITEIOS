//
//  FlowmagikHeader.swift
//  ERPLITEIOS
//

import SwiftUI

struct FlowmagikHeader: View {
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Flowmagik")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.brand)
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
