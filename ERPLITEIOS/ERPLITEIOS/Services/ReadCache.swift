//
//  ReadCache.swift
//  ERPLITEIOS
//
//  In-memory read cache for a future backend reader.
//  Mock business screens do not write records here, and nothing in this type touches disk.
//

import Foundation

enum ReadCachePolicy: Equatable {
    /// Always call the provider. Used by the mock catalog.
    case bypass
    /// Keep a value in memory until it is older than `freshFor` or the session ends.
    case memoryOnly(freshFor: TimeInterval)
}

struct CachedValue<T: Equatable>: Equatable {
    var value: T
    var accountLabel: String
    var storedAt: Date

    func isStale(now: Date, freshFor: TimeInterval) -> Bool {
        now.timeIntervalSince(storedAt) >= freshFor
    }
}

/// Process memory only. Sign-out removes every entry so the next account cannot read it.
final class ProtectedMemoryCache {
    private struct Entry {
        var accountLabel: String
        var storedAt: Date
        var value: Any
    }

    private var entries: [String: Entry] = [:]

    func store<T>(_ value: T, key: String, accountLabel: String, at date: Date) {
        entries[key] = Entry(accountLabel: accountLabel, storedAt: date, value: value)
    }

    func load<T>(_ type: T.Type, key: String, accountLabel: String) -> CachedValue<T>? {
        guard let entry = entries[key], entry.accountLabel == accountLabel, let value = entry.value as? T else {
            return nil
        }
        return CachedValue(value: value, accountLabel: entry.accountLabel, storedAt: entry.storedAt)
    }

    func invalidate(accountLabel: String) {
        entries = entries.filter { $0.value.accountLabel != accountLabel }
    }

    func invalidateAll() {
        entries.removeAll()
    }

    var isEmpty: Bool { entries.isEmpty }
}

enum ReadThrough {
    static func load<T: Equatable>(
        policy: ReadCachePolicy,
        cache: ProtectedMemoryCache,
        key: String,
        accountLabel: String,
        now: Date,
        fetch: () async throws -> T
    ) async throws -> T {
        switch policy {
        case .bypass:
            return try await fetch()
        case .memoryOnly(let freshFor):
            if let cached = cache.load(T.self, key: key, accountLabel: accountLabel),
               !cached.isStale(now: now, freshFor: freshFor) {
                return cached.value
            }
            let value = try await fetch()
            cache.store(value, key: key, accountLabel: accountLabel, at: now)
            return value
        }
    }
}
