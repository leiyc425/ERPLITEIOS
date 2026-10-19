//
//  IntakeDraft.swift
//  ERPLITEIOS
//
//  Unsent drafts live in memory. They are not ERP records and they are not saved to disk.
//

import Foundation
import UIKit

enum IntakeKind: String, Equatable, CaseIterable, Identifiable {
    case sku
    case inventoryItem
    case asset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sku: "SKU product"
        case .inventoryItem: "Physical inventory unit"
        case .asset: "Fixed asset"
        }
    }
}

struct DraftImage: Equatable {
    var jpeg: Data
    var pixelWidth: Int
    var pixelHeight: Int
}

enum DraftImageFailure: Equatable, LocalizedError {
    case tooLarge
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooLarge: "That image is too large to attach."
        case .unreadable: "That image could not be read."
        }
    }
}

enum DraftImagePrep {
    static let maxBytes = 8_000_000
    static let maxEdge: CGFloat = 1600

    static func prepare(_ data: Data) -> Result<DraftImage, DraftImageFailure> {
        guard data.count <= maxBytes else { return .failure(.tooLarge) }
        guard let image = UIImage(data: data) else { return .failure(.unreadable) }
        let oriented = image.normalizedOrientation()
        let scaled = oriented.scaled(maxEdge: maxEdge)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.82) else { return .failure(.unreadable) }
        return .success(DraftImage(
            jpeg: jpeg,
            pixelWidth: Int(scaled.size.width * scaled.scale),
            pixelHeight: Int(scaled.size.height * scaled.scale)
        ))
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func scaled(maxEdge: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxEdge, longest > 0 else { return self }
        let ratio = maxEdge / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct IntakeDraft: Equatable {
    var kind: IntakeKind
    /// Exact captured code. This is not an ERP number and it is not trimmed.
    var capturedCode: String
    var symbology: ScanSymbology
    var name: String = ""
    var details: String = ""
    var skuCode: String = ""
    var externalReference: String = ""
    var acquiredOrInServiceDate: String = ""
    var cost: String = "0.00"
    var assetType: String = "OTHER"
    var image: DraftImage?
    var isActive: Bool = true

    var reviewNote: String {
        "This draft has not been sent. It is not an inventory movement, asset, or ERP number."
    }
}

enum DraftValidation: Equatable {
    case ready
    case invalid(String)
}

enum IntakeValidation {
    static func validate(_ draft: IntakeDraft) -> DraftValidation {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .invalid("Name is required.") }
        switch draft.kind {
        case .sku:
            if draft.skuCode.isEmpty { return .invalid("SKU code is required. It is kept exactly as captured.") }
            return .ready
        case .inventoryItem, .asset:
            if !isDay(draft.acquiredOrInServiceDate) {
                return .invalid("Enter a date as YYYY-MM-DD.")
            }
            guard let cost = Decimal(string: draft.cost), cost >= 0 else {
                return .invalid("Cost must be a non-negative CAD amount.")
            }
            return .ready
        }
    }

    private static func isDay(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let parts = value.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else { return false }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}

@Observable
final class IntakeDraftStore {
    var draft: IntakeDraft?

    func discard() {
        draft = nil
    }
}
