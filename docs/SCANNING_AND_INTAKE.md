# Scanning and intake

Inspected Django checkout: `cf141a1da0e12d0f49e6daea19348c2622355a27` on `dev`. The Django tree was not modified. A model in that checkout is not a JSON API. The only machine-readable route verified there remains `GET /health/`.

## Verified in Django

`SKUProduct.sku` is a unique case-insensitive code, maximum 64 characters. It is not the row's primary key. Stock quantities change only through server stock services. `available` is `on_hand - reserved`.

`InventoryItem.inventory_number` is allocated by the server. `external_inventory_number` is optional, and unique case-insensitively when it is not blank. The model comment says it is not a SKU. A physical unit is one item. Status values are `IN_STOCK`, `RESERVED`, and `SOLD`. `purchase_cost` is a non-negative CAD amount.

`BusinessAsset.asset_number` is allocated by the server when a row is created. `name` is required. `asset_type` is one of `SERVER`, `LAPTOP`, `WORKSTATION`, `MONITOR`, `NETWORK_EQUIPMENT`, `UPS`, `PRINTER_SCANNER`, `OFFICE_EQUIPMENT`, and `OTHER`. Status is `IN_USE`, `IDLE`, or `DISPOSED`. `in_service_date` is required. `original_cost` is a non-negative amount. There is no serial, barcode, QR, or asset-tag column.

No product-image model was found. `documents.Document` stores a file on a sale or an expense. `CompanyLogoRevision` is invoice branding. Neither is a SKU photo, and neither is a verified upload API for this app.

Permissions and audit events for asset and inventory writes live on the server. This app does not create those rows.

## Not verified

There is no barcode, QR, Data Matrix, or serial column to treat as a global identifier. A code can match more than one record type. A code is not a quantity. A scan does not authorize a stock movement.

No authenticated lookup or create endpoint was found. Everything under "Proposed" in [MOBILE_API_REQUIREMENTS.md](MOBILE_API_REQUIREMENTS.md) is not implemented.

## What the app does

Recognition and lookup are separate.

A `ScanCapture` keeps the raw payload, the symbology, whether the source was the camera or the keyboard, and the time. The payload is not trimmed and not case-folded. Django uniqueness is case-insensitive; this client does not copy that rule, because folding could hide two different raw codes. Tests lock the exact match.

These payloads are not treated as identifiers:

- An empty string.
- A string longer than 512 characters.
- A string whose scheme is `http` or `https`. The address is not opened and nothing in the payload is executed.

Lookup uses the in-memory sample catalog. It compares the raw payload with `sku`, `inventory_number`, a non-empty `external_inventory_number`, and `asset_number`. One item contributes at most one match even if both of its numbers are equal. The result is one match, several matches, no matches, an unsupported payload, lookup unavailable, or lookup failed. The sample catalog's origin is `mock`.

Several matches open a choice list. The app does not pick the first row.

A mock miss says that no sample record uses the code. It does not say the record is absent from ERP Lite.

The sample code `SHARED-CODE` is both a SKU with zero available quantity and an asset, so the dashboard available total stays 6.

## Drafts

Drafts are unsent and live in `IntakeDraftStore` only. They are discarded on sign-out, session expiry, and explicit discard. They are not written to UserDefaults, the keychain, Core Data, SwiftData, or a file. Quitting the app drops them. The app does not assign `inventory_number`, `asset_number`, or an invoice number.

| Draft | Captured code | Fields the form edits |
| --- | --- | --- |
| SKU product | Provisional `sku` text. Not a database id. | Name, details, the code, active flag. Quantity is not set. |
| Physical unit | Provisional external reference. Not `inventory_number`. | Name, details, date `YYYY-MM-DD`, non-negative cost. |
| Fixed asset | Not stored as `asset_number`. There is no barcode column. | Name, details, type text defaulting to `OTHER`, in-service date, non-negative cost. |

Name emptiness is checked after trimming spaces, because the server strips names on save. The captured code is not trimmed. Mapping of the captured code onto `sku` or `external_inventory_number` is provisional until a create API exists. Asset type choices are not enforced beyond the text the user types. The review screen has no submit action.

## Camera and photos

VisionKit `DataScannerViewController` scans QR, Data Matrix, Code 128, Code 39, EAN-13, EAN-8, and UPC-E when `isSupported` and `isAvailable` are true and camera permission allows it. Vision often reports UPC-A as EAN-13. The app records the Vision symbology identifier and maps the known ones. Anything else is labeled unrecognized and is still looked up as raw text if it is not a web address.

The Simulator reports scanning as unsupported. Manual entry is the complete alternative. A denied camera shows a Settings link. Restricted access and a missing camera explain that manual entry still works.

The first accepted camera code pauses scanning. The same payload and symbology are also ignored for 1.5 seconds after an accept. Scanning resumes only from "Scan another code". The camera view stops scanning when it is removed. The photo camera sheet closes when the app is no longer active.

A product photo can be chosen with `PhotosPicker` or, when the device has a camera, taken with `UIImagePickerController`. The image is oriented upright, scaled so the long edge is at most 1600 pixels, and re-encoded as JPEG so location metadata from the source is not kept. Input larger than 8,000,000 bytes is rejected. The JPEG stays on the draft. It is not uploaded, not written to a file, and not saved to the photo library. Cancel leaves the current attachment in place. Replace and remove are explicit.

One image is attached in this phase. A later draft can hold an ordered list of the same `DraftImage` values plus an index for the primary image. That still requires a verified upload and association API before any bytes leave the device.

`NSCameraUsageDescription` explains scanning and the unsent product photo. The system photo picker does not add a photo-library usage string.

Scanned values and images are not sent to `GET /health/` or any other URL.
