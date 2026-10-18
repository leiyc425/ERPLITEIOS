//
//  TokenStore.swift
//  ERPLITEIOS
//

import Foundation

/// Opaque value kept on device. Phase 0 stores mock session markers, not ERP Lite tokens.
struct StoredCredential: Codable, Equatable {
    var secret: String
    var accountLabel: String
    var expiresAt: Date?
    var isMock: Bool
}

protocol TokenStoring {
    func save(_ credential: StoredCredential) throws
    func load() throws -> StoredCredential?
    func clear() throws
}

enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidData
}

/// In-memory store for previews and tests. It is not a substitute for the keychain in the running app.
final class InMemoryTokenStore: TokenStoring {
    private var credential: StoredCredential?

    func save(_ credential: StoredCredential) throws {
        self.credential = credential
    }

    func load() throws -> StoredCredential? {
        credential
    }

    func clear() throws {
        credential = nil
    }
}
