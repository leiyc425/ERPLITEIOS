import Foundation
import Testing
import UIKit
@testable import ERPLITEIOS

@MainActor
struct ScanTests {
    private let clock = ManualClock(Date(timeIntervalSince1970: 1_800_000_000))

    @Test func symbologyMappingKeepsUnknownCodes() {
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyQR") == .qr)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyDataMatrix") == .dataMatrix)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyCode128") == .code128)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyCode39") == .code39)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyEAN13") == .ean13)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyEAN8") == .ean8)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyUPCE") == .upce)
        #expect(ScanSymbology.fromVisionIdentifier("VNBarcodeSymbologyAztec") == .unrecognized)
    }

    @Test func codesAreNotTrimmedOrCaseFolded() {
        #expect(CodeInterpretation.classify("") == .empty)
        #expect(CodeInterpretation.classify(" 0001") == .identifier)
        #expect(CodeInterpretation.classify(String(repeating: "A", count: 513)) == .tooLong)
        #expect(CodeInterpretation.classify("https://example.com/item/1") == .webAddress)
        #expect(CodeInterpretation.classify("HTTP://EXAMPLE.com/x") == .webAddress)
        #expect(CodeInterpretation.classify("sample-sku") == .identifier)
    }

    @Test func duplicateCameraReadsAreSuppressedUntilResume() {
        var gate = ScanGate()
        let first = capture("0001", at: clock.date)
        let accepted = gate.accept(first, now: clock.date)
        let paused = gate.accept(first, now: clock.date.addingTimeInterval(2))
        gate.resume()
        let insideWindow = gate.accept(first, now: clock.date.addingTimeInterval(0.4))
        let afterWindow = gate.accept(first, now: clock.date.addingTimeInterval(2))
        #expect(accepted)
        #expect(!paused)
        #expect(!insideWindow)
        #expect(afterWindow)
    }

    @Test func oneMatchMultiMatchAndMissStayMock() async {
        let resolver = CatalogScanResolver(catalog: .sample)
        let one = await resolver.resolve(capture("0001"))
        #expect(one == .match(ScanMatch(id: "unit-1", kind: .inventoryItem, title: "Sample physical unit", identifier: "0001", origin: .mock)))

        let sku = await resolver.resolve(capture("SAMPLE-SKU"))
        guard case .match(let skuMatch) = sku else {
            Issue.record("expected one SKU")
            return
        }
        #expect(skuMatch.kind == .sku)
        #expect(skuMatch.origin == .mock)

        let legacy = await resolver.resolve(capture("LEGACY-3"))
        guard case .match(let legacyMatch) = legacy else {
            Issue.record("expected the external number")
            return
        }
        #expect(legacyMatch.kind == .inventoryItem)

        let shared = await resolver.resolve(capture("SHARED-CODE"))
        guard case .matches(let matches) = shared else {
            Issue.record("expected a choice")
            return
        }
        #expect(matches.map(\.kind) == [.sku, .asset])
        #expect(matches.allSatisfy { $0.origin == .mock })

        let missed = await resolver.resolve(capture("UNKNOWN-99"))
        #expect(missed == .none(origin: .mock))
        #expect(await resolver.resolve(capture("sample-sku")) == .none(origin: .mock))
        #expect(await resolver.resolve(capture(" 0001")) == .none(origin: .mock))
    }

    @Test func webAddressesAndForcedFailuresDoNotMatch() async {
        let resolver = CatalogScanResolver(catalog: .sample)
        let address = await resolver.resolve(capture("https://example.com/item/1"))
        #expect(address == .unsupported("This scan is a web address. It was not opened."))
        #expect(await resolver.resolve(capture("")) == .unsupported("Enter a code."))

        var unavailable = CatalogScanResolver(catalog: .sample)
        unavailable.forced = .unavailable
        #expect(await unavailable.resolve(capture("0001")) == .unavailable)

        var failed = CatalogScanResolver(catalog: .sample)
        failed.forced = .failed("lookup failed")
        #expect(await failed.resolve(capture("0001")) == .failed("lookup failed"))
    }

    @Test func workflowDoesNotAutoSelectAndCanStartADraft() async {
        let drafts = IntakeDraftStore()
        let model = ScanWorkflowModel(
            resolver: CatalogScanResolver(catalog: .sample),
            drafts: drafts,
            clock: clock,
            availability: .unsupported
        )
        model.manualEntry = "SHARED-CODE"
        await model.submitManual()
        guard case .result(.matches(let matches)) = model.step else {
            Issue.record("expected matches")
            return
        }
        #expect(matches.count == 2)
        #expect(model.drafts.draft == nil)

        model.manualEntry = "UNKNOWN-99"
        await model.submitManual()
        model.startDraft()
        model.chooseType(.inventoryItem)
        #expect(model.drafts.draft?.externalReference == "UNKNOWN-99")
        #expect(model.drafts.draft?.kind == .inventoryItem)
        model.reviewDraft()
        #expect(model.validationMessage == "Name is required.")
        model.drafts.draft?.name = "Spare unit"
        model.drafts.draft?.acquiredOrInServiceDate = "2026-10-18"
        model.reviewDraft()
        #expect(model.step == .review)

        model.discardDraft()
        #expect(drafts.draft == nil)
        #expect(model.step == .entry)
    }

    @Test func draftValidationRejectsBadDatesAndCosts() {
        var draft = IntakeDraft(kind: .asset, capturedCode: "TAG", symbology: .code39, name: "Printer")
        draft.acquiredOrInServiceDate = "18-10-2026"
        #expect(IntakeValidation.validate(draft) == .invalid("Enter a date as YYYY-MM-DD."))
        draft.acquiredOrInServiceDate = "2026-10-18"
        draft.cost = "-1"
        #expect(IntakeValidation.validate(draft) == .invalid("Cost must be a non-negative CAD amount."))
        draft.cost = "0.00"
        #expect(IntakeValidation.validate(draft) == .ready)

        let sku = IntakeDraft(kind: .sku, capturedCode: "ABC", symbology: .manual, name: "Cable", skuCode: "")
        #expect(IntakeValidation.validate(sku) == .invalid("SKU code is required. It is kept exactly as captured."))
    }

    @Test func photoCancelReplaceAndRemoveStayInMemory() {
        let drafts = IntakeDraftStore()
        let model = ScanWorkflowModel(
            resolver: CatalogScanResolver(catalog: .empty),
            drafts: drafts,
            clock: clock,
            availability: .noCamera
        )
        model.chooseTypeWithoutResult(kind: .sku, code: "ABC")
        model.cancelPhoto()
        #expect(drafts.draft?.image == nil)

        let first = imageData(size: CGSize(width: 20, height: 10), color: .red)
        model.attachPhoto(first)
        let attached = drafts.draft?.image
        #expect(attached != nil)

        model.cancelPhoto()
        #expect(drafts.draft?.image == attached)

        let replacement = imageData(size: CGSize(width: 2000, height: 10), color: .blue)
        model.attachPhoto(replacement)
        #expect(drafts.draft?.image?.jpeg != attached?.jpeg)
        #expect((drafts.draft?.image?.pixelWidth ?? 0) <= 1600)

        model.removePhoto()
        #expect(drafts.draft?.image == nil)
        #expect(DraftImagePrep.prepare(Data(count: DraftImagePrep.maxBytes + 1)) == .failure(.tooLarge))
        #expect(DraftImagePrep.prepare(Data("not-an-image".utf8)) == .failure(.unreadable))
    }

    @Test func simulatorScannerIsUnsupportedAndGuidanceIsExplicit() {
        #expect(DeviceScanner.availability == .unsupported)
        #expect(ScannerAvailability.denied.guidance.contains("Settings"))
        #expect(ScannerAvailability.restricted.guidance.contains("restricted"))
        #expect(ScannerAvailability.noCamera.guidance.contains("no camera"))
        #expect(DeviceScanner.classify(hasCamera: false, status: .authorized, scannerSupported: true) == .noCamera)
        #expect(DeviceScanner.classify(hasCamera: true, status: .denied, scannerSupported: true) == .denied)
        #expect(DeviceScanner.classify(hasCamera: true, status: .restricted, scannerSupported: true) == .restricted)
        #expect(DeviceScanner.classify(hasCamera: true, status: .authorized, scannerSupported: false) == .unsupported)
        #expect(DeviceScanner.classify(hasCamera: true, status: .authorized, scannerSupported: true) == .ready)
    }

    @Test func repeatedCameraAcceptanceDoesNotResolveTwice() async {
        let resolver = CountingResolver()
        let model = ScanWorkflowModel(
            resolver: resolver,
            drafts: IntakeDraftStore(),
            clock: clock,
            availability: .ready
        )
        let read = capture("0001")
        await model.acceptCamera(read)
        await model.acceptCamera(read)
        #expect(resolver.count == 1)
        model.resumeScanning()
        await model.acceptCamera(read)
        #expect(resolver.count == 1)
    }

    private func capture(_ payload: String, at date: Date? = nil) -> ScanCapture {
        ScanCapture(
            payload: payload,
            symbology: .code128,
            visionIdentifier: "VNBarcodeSymbologyCode128",
            source: .camera,
            recognizedAt: date ?? clock.date
        )
    }

    private func imageData(size: CGSize, color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}

private extension ScanWorkflowModel {
    func chooseTypeWithoutResult(kind: IntakeKind, code: String) {
        manualEntry = code
        drafts.draft = IntakeDraft(kind: kind, capturedCode: code, symbology: .manual, skuCode: code)
    }
}

private final class CountingResolver: ScanResolving {
    var count = 0

    func resolve(_ capture: ScanCapture) async -> LookupOutcome {
        count += 1
        return .none(origin: .mock)
    }
}
