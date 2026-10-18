//
//  JSONCoding.swift
//  ERPLITEIOS
//

import Foundation

/// Provisional JSON dates use ISO-8601.
/// Key conversion stays off until an ERP Lite contract defines its JSON shape.
enum JSONCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try makeEncoder().encode(value)
        } catch {
            throw APIError.encodingFailed
        }
    }
}
