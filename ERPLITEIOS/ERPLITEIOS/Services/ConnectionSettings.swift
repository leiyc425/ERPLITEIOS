//
//  ConnectionSettings.swift
//  ERPLITEIOS
//
//  Stores a development base URL. This is not a credential.
//

import Foundation
import Observation

protocol DevelopmentEndpointStoring: AnyObject {
    func load() -> String
    func save(_ value: String)
}

final class MemoryEndpointStore: DevelopmentEndpointStoring {
    private var value: String

    init(_ value: String = "") {
        self.value = value
    }

    func load() -> String { value }

    func save(_ value: String) {
        self.value = value
    }
}

final class UserDefaultsEndpointStore: DevelopmentEndpointStoring {
    var defaults: UserDefaults = .standard
    var key = "developmentBaseURL"

    func load() -> String {
        defaults.string(forKey: key) ?? ""
    }

    func save(_ value: String) {
        if value.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(value, forKey: key)
        }
    }
}

@MainActor
@Observable
final class ConnectionSettings {
    private let store: any DevelopmentEndpointStoring
    let bundled: AppConfiguration
    var draft: String
    private(set) var overrideURL: URL?
    private(set) var validationMessage: String?
    private(set) var revision = 0

    init(bundled: AppConfiguration, store: any DevelopmentEndpointStoring) {
        self.bundled = bundled
        self.store = store
        let saved = store.load().trimmingCharacters(in: .whitespacesAndNewlines)
        if saved.isEmpty {
            draft = ""
            overrideURL = nil
        } else if case .success(let url) = AppConfigurationLoader.makeBaseURL(saved) {
            draft = url.absoluteString
            overrideURL = url
        } else {
            draft = ""
            overrideURL = nil
            store.save("")
        }
    }

    var effectiveBaseURL: URL? {
        overrideURL ?? bundled.baseURL
    }

    var modeSummary: String {
        "Mock business data. A base URL is used only for GET /health/."
    }

    var limitationSummary: String {
        "A successful health check does not turn on client, inventory, sale, or invoice APIs. Those JSON routes are not in the inspected backend. App Transport Security is unchanged, and this screen does not add a cleartext exception."
    }

    func saveDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clear()
            return
        }
        switch AppConfigurationLoader.makeBaseURL(trimmed) {
        case .success(let url):
            overrideURL = url
            draft = url.absoluteString
            store.save(url.absoluteString)
            validationMessage = nil
            revision += 1
        case .failure(let error):
            validationMessage = error.localizedDescription
        }
    }

    func clear() {
        overrideURL = nil
        draft = ""
        store.save("")
        validationMessage = nil
        revision += 1
    }
}
