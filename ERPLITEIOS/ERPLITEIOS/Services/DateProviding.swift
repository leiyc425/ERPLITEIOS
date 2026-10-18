//
//  DateProviding.swift
//  ERPLITEIOS
//

import Foundation

protocol DateProviding {
    func now() -> Date
}

struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}

/// Clock tests can move without sleeping.
final class ManualClock: DateProviding {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }

    func now() -> Date { date }

    func advance(by interval: TimeInterval) {
        date.addTimeInterval(interval)
    }
}
