//
//  ScanWorkflowView.swift
//  ERPLITEIOS
//

import PhotosUI
import SwiftUI
import Vision
import VisionKit

struct ScanWorkflowView: View {
    @Bindable var model: ScanWorkflowModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDiscard = false
    @State private var selectedMatch: ScanMatch?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoCamera = false
    @State private var manual = ""

    var body: some View {
        NavigationStack {
            List {
                switch model.step {
                case .entry:
                    entry
                case .result(let outcome):
                    result(outcome)
                case .chooseType:
                    typeChoices
                case .editing:
                    editor
                case .review:
                    review
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { requestClose() }
                        .accessibilityIdentifier("scan.close")
                }
            }
            .confirmationDialog("Discard this unsent draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard draft", role: .destructive) {
                    model.discardDraft()
                    dismiss()
                }
                .accessibilityIdentifier("scan.confirmDiscard")
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("The draft is only in memory. Closing it removes the code and any photo.")
            }
            .interactiveDismissDisabled(model.hasUnsentDraft)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    showPhotoCamera = false
                }
            }
        }
        .accessibilityIdentifier("scan.root")
    }

    private var entry: some View {
        Group {
            Section {
                Text(model.availability.guidance)
                if model.availability == .denied, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settings)
                }
            }
            if model.availability == .ready, scenePhase == .active {
                Section {
                    BarcodeCameraView { capture in
                        Task { await model.acceptCamera(capture) }
                    }
                    .frame(minHeight: 280)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("scan.camera")
                }
            }
            Section("Enter a code") {
                TextField("Code", text: $manual)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("scan.manual")
                Button("Look up") {
                    model.manualEntry = manual
                    Task { await model.submitManual() }
                }
                .accessibilityIdentifier("scan.lookup")
                Text("The code is kept exactly as typed. A web address is not opened.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func result(_ outcome: LookupOutcome) -> some View {
        switch outcome {
        case .match(let match):
            matchDetail(match)
            anotherScan
        case .matches(let matches):
            Section("Choose a record") {
                Text("More than one sample record uses this exact code. Nothing is selected automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(matches) { match in
                    Button {
                        selectedMatch = match
                    } label: {
                        VStack(alignment: .leading) {
                            Text(match.title)
                            Text("\(match.kind.label) · \(match.identifier)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("scan.choice.\(match.id)")
                }
            }
            if let selectedMatch {
                matchDetail(selectedMatch)
            }
            anotherScan
        case .none(let origin):
            Section {
                Text(origin == .mock
                     ? "No sample record uses this exact code. This is a mock lookup, so it does not prove the code is missing from ERP Lite."
                     : "No verified ERP Lite record uses this exact code.")
                    .accessibilityIdentifier("scan.none")
                Button("Prepare an unsent draft") { model.startDraft() }
                    .accessibilityIdentifier("scan.startDraft")
            }
            anotherScan
        case .unsupported(let message):
            Section {
                Text(message)
                    .accessibilityIdentifier("scan.unsupported")
            }
            anotherScan
        case .unavailable:
            Section {
                Text("Lookup is unavailable. No request was sent.")
                    .accessibilityIdentifier("scan.unavailable")
            }
            anotherScan
        case .failed(let message):
            Section {
                Text(message)
                    .accessibilityIdentifier("scan.failed")
            }
            anotherScan
        }
    }

    private func matchDetail(_ match: ScanMatch) -> some View {
        Section(match.kind.label) {
            Text(match.title)
                .accessibilityIdentifier("scan.matchTitle")
            LabeledContent("Identifier", value: match.identifier)
            Text(match.origin == .mock
                 ? "Mock sample. This was not loaded from ERP Lite."
                 : "Verified ERP Lite record.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("scan.match.\(match.id)")
        }
    }

    private var anotherScan: some View {
        Section {
            Button("Scan another code") {
                manual = ""
                model.manualEntry = ""
                model.resumeScanning()
            }
                .accessibilityIdentifier("scan.again")
        }
    }

    private var typeChoices: some View {
        Section("What should this draft describe?") {
            Text("The captured code is not an ERP number. Nothing is created in ERP Lite.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(IntakeKind.allCases) { kind in
                Button(kind.label) { model.chooseType(kind) }
                    .accessibilityIdentifier("scan.type.\(kind.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if model.drafts.draft != nil {
            Section("Unsent draft") {
                Text("This stays on the device only until you close it, sign out, or the mock session expires. It is not saved and it will not survive quitting the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Name", text: draftBinding(\.name))
                    .accessibilityIdentifier("scan.name")
                TextField("Details", text: draftBinding(\.details), axis: .vertical)
            }
            kindFields
            photoSection
            if let validationMessage = model.validationMessage {
                Section { Text(validationMessage).foregroundStyle(.red) }
            }
            Section {
                Button("Review draft") { model.reviewDraft() }
                    .accessibilityIdentifier("scan.review")
                Button("Discard draft", role: .destructive) { model.discardDraft() }
                    .accessibilityIdentifier("scan.discard")
            }
        }
    }

    @ViewBuilder
    private var kindFields: some View {
        if let kind = model.drafts.draft?.kind {
            switch kind {
            case .sku:
                Section("SKU") {
                    TextField("SKU code", text: draftBinding(\.skuCode))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("scan.skuCode")
                    Toggle("Active", isOn: draftBoolBinding(\.isActive))
                    Text("Quantity is not set here. Receiving stays on the server. The code is a provisional SKU, not a database id.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .inventoryItem:
                Section("Physical unit") {
                    LabeledContent("Provisional external reference", value: model.drafts.draft?.externalReference ?? "")
                    TextField("Date YYYY-MM-DD", text: draftBinding(\.acquiredOrInServiceDate))
                        .accessibilityIdentifier("scan.date")
                    TextField("Purchase cost CAD", text: draftBinding(\.cost))
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("scan.cost")
                    Text("ERP Lite assigns inventory_number. This draft does not.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .asset:
                Section("Asset") {
                    TextField("Type", text: draftBinding(\.assetType))
                        .accessibilityIdentifier("scan.assetType")
                    TextField("In service YYYY-MM-DD", text: draftBinding(\.acquiredOrInServiceDate))
                        .accessibilityIdentifier("scan.date")
                    TextField("Original cost CAD", text: draftBinding(\.cost))
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("scan.cost")
                    Text("ERP Lite has no barcode column on assets. The captured code is not an asset number. The server assigns asset_number.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            if let image = model.drafts.draft?.image, let preview = UIImage(data: image.jpeg) {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .accessibilityLabel("Draft photo preview")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text(model.drafts.draft?.image == nil ? "Choose photo" : "Replace photo")
            }
            .accessibilityIdentifier("scan.photo")
            .onChange(of: photoItem) { _, item in
                guard let item else {
                    model.cancelPhoto()
                    return
                }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        model.attachPhoto(data)
                    } else {
                        model.cancelPhoto()
                    }
                    photoItem = nil
                }
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera), scenePhase == .active {
                Button("Take photo") { showPhotoCamera = true }
                    .accessibilityIdentifier("scan.cameraPhoto")
            } else {
                Text("This device cannot take a photo. A library photo can still be attached to this unsent draft.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.drafts.draft?.image != nil {
                Button("Remove photo", role: .destructive) { model.removePhoto() }
                    .accessibilityIdentifier("scan.removePhoto")
            }
            if let imageMessage = model.imageMessage {
                Text(imageMessage)
                    .foregroundStyle(.red)
            }
            Text("The photo is not uploaded and is not saved to your library.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPhotoCamera) {
            PhotoCameraPicker(
                onImage: { data in
                    model.attachPhoto(data)
                    showPhotoCamera = false
                },
                onCancel: {
                    model.cancelPhoto()
                    showPhotoCamera = false
                }
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var review: some View {
        if let draft = model.drafts.draft {
            Section("Review") {
                Text(draft.reviewNote)
                    .accessibilityIdentifier("scan.reviewNote")
                LabeledContent("Kind", value: draft.kind.label)
                LabeledContent("Captured code", value: draft.capturedCode)
                LabeledContent("Symbology", value: draft.symbology.label)
                LabeledContent("Name", value: draft.name)
                if draft.kind == .sku {
                    LabeledContent("SKU code", value: draft.skuCode)
                }
                if draft.kind == .inventoryItem {
                    LabeledContent("External reference", value: draft.externalReference)
                }
                Text("Submission is not available. This screen does not create stock, an asset, a document number, or an audit event.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Back to draft") { model.step = .editing }
                Button("Discard draft", role: .destructive) { model.discardDraft() }
                    .accessibilityIdentifier("scan.discard")
            }
        }
    }

    private func requestClose() {
        if model.hasUnsentDraft {
            confirmDiscard = true
        } else {
            dismiss()
        }
    }

    private func draftBinding(_ keyPath: WritableKeyPath<IntakeDraft, String>) -> Binding<String> {
        Binding(
            get: { model.drafts.draft?[keyPath: keyPath] ?? "" },
            set: { model.drafts.draft?[keyPath: keyPath] = $0 }
        )
    }

    private func draftBoolBinding(_ keyPath: WritableKeyPath<IntakeDraft, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.drafts.draft?[keyPath: keyPath] ?? false },
            set: { model.drafts.draft?[keyPath: keyPath] = $0 }
        )
    }
}

struct BarcodeCameraView: UIViewControllerRepresentable {
    var onCode: (ScanCapture) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.qr, .dataMatrix, .code128, .code39, .ean13, .ean8, .upce])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (ScanCapture) -> Void

        init(onCode: @escaping (ScanCapture) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                guard case .barcode(let barcode) = item else { continue }
                let raw = barcode.payloadStringValue ?? ""
                let identifier = barcode.observation.symbology.rawValue
                onCode(ScanCapture(
                    payload: raw,
                    symbology: ScanSymbology.fromVisionIdentifier(identifier),
                    visionIdentifier: identifier,
                    source: .camera,
                    recognizedAt: Date()
                ))
            }
        }
    }
}

struct PhotoCameraPicker: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImage: (Data) -> Void
        var onCancel: () -> Void

        init(onImage: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) else {
                onCancel()
                return
            }
            onImage(data)
        }
    }
}
