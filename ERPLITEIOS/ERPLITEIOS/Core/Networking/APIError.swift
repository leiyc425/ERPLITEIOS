//
//  APIError.swift
//  ERPLITEIOS
//

import Foundation

/// Transport failures for a future ERP Lite HTTP contract.
/// Response bodies are intentionally omitted so a payload cannot leak into UI or logs.
enum APIError: Error, Equatable, LocalizedError {
    case backendNotConfigured
    case invalidRequestURL
    case timedOut
    case cancelled
    case transport(String)
    case unacceptableStatus(code: Int)
    case decodingFailed
    case encodingFailed
    case unauthenticated
    case authenticationSchemeNotConfigured

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "No ERP Lite base URL is configured, so the request was not sent."
        case .invalidRequestURL:
            return "The request URL could not be built."
        case .timedOut:
            return "The request timed out."
        case .cancelled:
            return "The request was cancelled."
        case .transport(let description):
            return description
        case .unacceptableStatus(let code):
            return "The server returned HTTP \(code)."
        case .decodingFailed:
            return "The response could not be decoded."
        case .encodingFailed:
            return "The request body could not be encoded."
        case .unauthenticated:
            return "The request was rejected as unauthenticated."
        case .authenticationSchemeNotConfigured:
            return "ERP Lite has not published an authentication scheme, so credentials were not attached."
        }
    }
}
