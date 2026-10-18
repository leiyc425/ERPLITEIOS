//
//  Session.swift
//  ERPLITEIOS
//

import Foundation

/// Client-side sign-in snapshot.
/// This is not an ERP Lite user, employee, or token payload.
struct Session: Equatable {
    var accountLabel: String
    var expiresAt: Date?
    var isMock: Bool
}
