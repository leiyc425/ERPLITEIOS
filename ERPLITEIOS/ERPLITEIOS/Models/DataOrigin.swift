//
//  DataOrigin.swift
//  ERPLITEIOS
//

import Foundation

/// Distinguishes placeholders drawn by the app from values that came from ERP Lite.
enum DataOrigin: String, Equatable, Sendable {
    case mock
    case backend
}
