//
//  ScanModels.swift
//  ERPLITEIOS
//
//  Recognition is separate from ERP lookup. Payloads are kept exactly as captured.
//

import Foundation

enum ScanSymbology: String, Equatable, CaseIterable {
    case qr
    case dataMatrix
    case code128
    case code39
    case ean13
    case ean8
    case upce
    case manual
    case unrecognized

    var label: String {
        switch self {
        case .qr: "QR"
        case .dataMatrix: "Data Matrix"
        case .code128: "Code 128"
        case .code39: "Code 39"
        case .ean13: "EAN-13"
        case .ean8: "EAN-8"
        case .upce: "UPC-E"
        case .manual: "Manual entry"
        case .unrecognized: "Unrecognized symbology"
        }
    }

    /// Vision reports UPC-A as EAN-13. There is no separate UPC-A case.
    static func fromVisionIdentifier(_ identifier: String) -> ScanSymbology {
        switch identifier {
        case "VNBarcodeSymbologyQR": .qr
        case "VNBarcodeSymbologyDataMatrix": .dataMatrix
        case "VNBarcodeSymbologyCode128": .code128
        case "VNBarcodeSymbologyCode39": .code39
        case "VNBarcodeSymbologyEAN13": .ean13
        case "VNBarcodeSymbologyEAN8": .ean8
        case "VNBarcodeSymbologyUPCE": .upce
        default: .unrecognized
        }
    }
}

enum ScanInputSource: String, Equatable {
    case camera
    case manual
}

struct ScanCapture: Equatable {
    var payload: String
    var symbology: ScanSymbology
    var visionIdentifier: String?
    var source: ScanInputSource
    var recognizedAt: Date
}

enum CodeInterpretation: Equatable {
    case empty
    case webAddress
    case tooLong
    case identifier

    /// Does not trim. A web address is recognized only by its scheme prefix and is not opened.
    static func classify(_ raw: String) -> CodeInterpretation {
        if raw.isEmpty { return .empty }
        if raw.count > 512 { return .tooLong }
        let scheme = raw.prefix(while: { $0 != ":" }).lowercased()
        if raw.lowercased().hasPrefix("\(scheme)://"), scheme == "http" || scheme == "https" {
            return .webAddress
        }
        return .identifier
    }
}

enum ScanRecordKind: String, Equatable {
    case sku
    case inventoryItem
    case asset

    var label: String {
        switch self {
        case .sku: "SKU"
        case .inventoryItem: "Physical unit"
        case .asset: "Asset"
        }
    }
}

struct ScanMatch: Identifiable, Equatable {
    var id: String
    var kind: ScanRecordKind
    var title: String
    var identifier: String
    var origin: DataOrigin
}

enum LookupOutcome: Equatable {
    case match(ScanMatch)
    case matches([ScanMatch])
    case none(origin: DataOrigin)
    case unsupported(String)
    case unavailable
    case failed(String)
}

struct ScanGate {
    var isPaused = false
    private var lastPayload: String?
    private var lastSymbology: ScanSymbology?
    private var lastAcceptedAt: Date?
    var window: TimeInterval = 1.5

    mutating func accept(_ capture: ScanCapture, now: Date) -> Bool {
        guard !isPaused else { return false }
        if let lastPayload, let lastSymbology, let lastAcceptedAt,
           lastPayload == capture.payload,
           lastSymbology == capture.symbology,
           now.timeIntervalSince(lastAcceptedAt) < window {
            return false
        }
        lastPayload = capture.payload
        lastSymbology = capture.symbology
        lastAcceptedAt = now
        isPaused = true
        return true
    }

    mutating func resume() {
        isPaused = false
    }
}

protocol ScanResolving {
    func resolve(_ capture: ScanCapture) async -> LookupOutcome
}

struct FailedScanResolver: ScanResolving {
    var message: String

    func resolve(_ capture: ScanCapture) async -> LookupOutcome {
        .failed(message)
    }
}

struct CatalogScanResolver: ScanResolving {
    var catalog: ERPCatalog
    var forced: LookupOutcome?

    func resolve(_ capture: ScanCapture) async -> LookupOutcome {
        if let forced { return forced }
        let raw = capture.payload
        switch CodeInterpretation.classify(raw) {
        case .empty:
            return .unsupported("Enter a code.")
        case .webAddress:
            return .unsupported("This scan is a web address. It was not opened.")
        case .tooLong:
            return .unsupported("This code is longer than 512 characters.")
        case .identifier:
            break
        }
        var matches: [ScanMatch] = []
        for sku in catalog.skus where sku.sku == raw {
            matches.append(ScanMatch(
                id: "sku-\(sku.id)",
                kind: .sku,
                title: sku.name,
                identifier: sku.sku,
                origin: catalog.origin
            ))
        }
        for item in catalog.inventory where item.inventoryNumber == raw || (!item.externalInventoryNumber.isEmpty && item.externalInventoryNumber == raw) {
            matches.append(ScanMatch(
                id: "unit-\(item.id)",
                kind: .inventoryItem,
                title: item.name,
                identifier: item.inventoryNumber,
                origin: catalog.origin
            ))
        }
        for asset in catalog.assets where asset.assetNumber == raw {
            matches.append(ScanMatch(
                id: "asset-\(asset.id)",
                kind: .asset,
                title: asset.name,
                identifier: asset.assetNumber,
                origin: catalog.origin
            ))
        }
        switch matches.count {
        case 0:
            return .none(origin: catalog.origin)
        case 1:
            return .match(matches[0])
        default:
            return .matches(matches)
        }
    }
}
