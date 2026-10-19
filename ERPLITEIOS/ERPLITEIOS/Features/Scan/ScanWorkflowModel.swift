//
//  ScanWorkflowModel.swift
//  ERPLITEIOS
//

import AVFoundation
import Foundation
import Observation
import UIKit
import Vision
import VisionKit

enum ScannerAvailability: Equatable {
    case ready
    case denied
    case restricted
    case noCamera
    case unsupported

    var guidance: String {
        switch self {
        case .ready:
            "Point the camera at one code. Scanning pauses after a code is accepted."
        case .denied:
            "Camera access is off. Turn it on in Settings, or enter the code manually."
        case .restricted:
            "Camera access is restricted on this device. Enter the code manually."
        case .noCamera:
            "This device has no camera. Enter the code manually."
        case .unsupported:
            "Camera scanning is not available here. The Simulator has no scanner. Enter the code manually."
        }
    }
}

enum DeviceScanner {
    static var availability: ScannerAvailability {
        #if targetEnvironment(simulator)
        return .unsupported
        #else
        return hardwareAvailability
        #endif
    }

    static var hardwareAvailability: ScannerAvailability {
        classify(
            hasCamera: UIImagePickerController.isSourceTypeAvailable(.camera),
            status: AVCaptureDevice.authorizationStatus(for: .video),
            scannerSupported: DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        )
    }

    static func classify(hasCamera: Bool, status: AVAuthorizationStatus, scannerSupported: Bool) -> ScannerAvailability {
        guard hasCamera else { return .noCamera }
        switch status {
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined, .authorized:
            break
        @unknown default:
            return .unsupported
        }
        return scannerSupported ? .ready : .unsupported
    }
}

enum ScanStep: Equatable {
    case entry
    case result(LookupOutcome)
    case chooseType
    case editing
    case review
}

@Observable
final class ScanWorkflowModel {
    private let resolver: any ScanResolving
    private let clock: any DateProviding
    var drafts: IntakeDraftStore
    var availability: ScannerAvailability
    var manualEntry = ""
    var step: ScanStep = .entry
    var validationMessage: String?
    var imageMessage: String?
    private var gate = ScanGate()
    private var pendingCode = ""
    private var pendingSymbology: ScanSymbology = .manual

    init(
        resolver: any ScanResolving,
        drafts: IntakeDraftStore,
        clock: any DateProviding,
        availability: ScannerAvailability
    ) {
        self.resolver = resolver
        self.drafts = drafts
        self.clock = clock
        self.availability = availability
    }

    var hasUnsentDraft: Bool { drafts.draft != nil }

    func submitManual() async {
        let capture = ScanCapture(
            payload: manualEntry,
            symbology: .manual,
            visionIdentifier: nil,
            source: .manual,
            recognizedAt: clock.now()
        )
        await show(capture, gated: false)
    }

    func acceptCamera(_ capture: ScanCapture) async {
        guard gate.accept(capture, now: clock.now()) else { return }
        await show(capture, gated: true)
    }

    func resumeScanning() {
        gate.resume()
        validationMessage = nil
        step = .entry
    }

    func startDraft() {
        guard case .result(.none) = step else { return }
        step = .chooseType
    }

    func chooseType(_ kind: IntakeKind) {
        var draft = IntakeDraft(kind: kind, capturedCode: pendingCode, symbology: pendingSymbology)
        switch kind {
        case .sku:
            draft.skuCode = pendingCode
        case .inventoryItem:
            draft.externalReference = pendingCode
        case .asset:
            break
        }
        drafts.draft = draft
        validationMessage = nil
        step = .editing
    }

    func reviewDraft() {
        guard let draft = drafts.draft else { return }
        switch IntakeValidation.validate(draft) {
        case .ready:
            validationMessage = nil
            step = .review
        case .invalid(let message):
            validationMessage = message
        }
    }

    func discardDraft() {
        drafts.discard()
        validationMessage = nil
        imageMessage = nil
        step = .entry
    }

    func attachPhoto(_ data: Data) {
        switch DraftImagePrep.prepare(data) {
        case .success(let image):
            drafts.draft?.image = image
            imageMessage = nil
        case .failure(let error):
            imageMessage = error.localizedDescription
        }
    }

    func cancelPhoto() {
        imageMessage = nil
    }

    func removePhoto() {
        drafts.draft?.image = nil
        imageMessage = nil
    }

    private func show(_ capture: ScanCapture, gated: Bool) async {
        if !gated {
            _ = gate.accept(capture, now: capture.recognizedAt)
        }
        pendingCode = capture.payload
        pendingSymbology = capture.symbology
        let outcome = await resolver.resolve(capture)
        step = .result(outcome)
    }
}
