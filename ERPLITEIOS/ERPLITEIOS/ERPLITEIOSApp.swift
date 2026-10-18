//
//  ERPLITEIOSApp.swift
//  ERPLITEIOS
//

import SwiftUI

@main
struct ERPLITEIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel: AppModel

    init() {
        _appModel = State(initialValue: AppModel(dependencies: .live()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: appModel)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await appModel.refreshSessionIfNeeded() }
                }
        }
    }
}
