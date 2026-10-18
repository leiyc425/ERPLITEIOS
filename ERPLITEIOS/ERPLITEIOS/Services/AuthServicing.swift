//
//  AuthServicing.swift
//  ERPLITEIOS
//

import Foundation

enum AuthError: Error, Equatable, LocalizedError {
    case missingCredentials
    case inputTooLong
    case sessionExpired
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Enter a username and password. This mock sign-in does not check ERP Lite."
        case .inputTooLong:
            return "Use a shorter username and password for this mock sign-in."
        case .sessionExpired:
            return "This mock session expired on the device. Sign in again. No ERP Lite session was ended because none exists."
        case .storageFailed:
            return "The mock session could not be stored on this device."
        }
    }
}

protocol AuthServicing {
    func login(username: String, password: String) async throws -> Session
    func logout() async
    func restoreSession() async throws -> Session?
}
