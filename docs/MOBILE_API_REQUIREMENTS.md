# Mobile API requirements

Inspected Django checkout: `cf141a1da0e12d0f49e6daea19348c2622355a27` on `dev`. None of the routes below exist in that checkout. Each one is **NOT IMPLEMENTED**. Do not call them from the app. Do not invent the authentication scheme. The current session is HTML login, not a token API this client can assume.

The running app looks up codes only in the sample catalog. It does not create SKUs, inventory items, assets, stock movements, receipts, reservations, shipments, invoices, documents, or audit events.

## Already verified

`GET /health/` returns a small JSON status. It is not a barcode lookup and must not receive scan payloads or images.

## Proposed and NOT IMPLEMENTED

### Authenticated barcode lookup

`NOT IMPLEMENTED`

Need an authenticated read that accepts the raw payload and the symbology and returns every matching SKU, inventory item, and asset. The server must define whether matching is case-sensitive. The client currently compares exact strings. A payload may match more than one record type. An empty result must mean "no row matched," which is different from the client's mock miss.

### SKU lookup

`NOT IMPLEMENTED`

Need a read by the `sku` code, not by assuming the code is the primary key. The response should include the stored code, name, active flag, and the server's on-hand, reserved, and available quantities. The client must not compute a stock change from a scan.

### Inventory item lookup

`NOT IMPLEMENTED`

Need a read by `inventory_number` and by non-blank `external_inventory_number`. The response should say which field matched. `external_inventory_number` is not a SKU.

### Asset lookup

`NOT IMPLEMENTED`

Need a read by `asset_number`. There is no barcode column on `BusinessAsset`. A future tag field has to be added on the server before the client can treat a scan as an asset tag. Until then, a scanned code is only a provisional note on an unsent draft.

### Record creation and validation

`NOT IMPLEMENTED`

Need separate create operations for a SKU, one physical inventory unit, and one fixed asset. The server already allocates `inventory_number` and `asset_number`. The client must not send those numbers as authoritative ids. SKU creation must not set on-hand quantity; receiving stays in the stock services. Validation errors must come back without a partial write. Required fields must be taken from the Django models that exist at that time, not from this document.

### Image upload and association

`NOT IMPLEMENTED`

Need a product-image resource, a byte limit, an allowed content type, and a way to mark one image as primary. This document does not assume multipart form upload. No product-image model exists today. Sale and expense documents and company logos are different records. The client keeps one in-memory JPEG until a contract exists.

### Duplicate detection

`NOT IMPLEMENTED`

Need the server to report an existing `sku`, `external_inventory_number`, or any future barcode before a create is committed. Case rules belong to the server. The client must show the existing rows instead of creating another one.

### Permissions

`NOT IMPLEMENTED`

Need the server to say which account may look up codes, create each record type, and attach images. A successful scan is not permission to write.

### Server-side audit events

`NOT IMPLEMENTED`

Creates, stock changes, and asset registration already have server audit behavior in Django. The client must not write audit rows. A future create response can include the server's event id if the API chooses to return one.

### Idempotency and atomic operations

`NOT IMPLEMENTED`

A create that also stores an image, or a receive that changes stock, needs one server transaction and an idempotency key so a retry does not double-post. The client does not send those requests in this phase.
