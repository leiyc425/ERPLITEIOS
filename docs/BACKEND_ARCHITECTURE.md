# Backend architecture

Inspected read-only from `/Users/yclei/Desktop/ERPLITE` at commit `cf141a1` (`dev`, tracking `origin/dev`). The previous iOS audit used `f75a051` on `main`. No backend file was modified.

ERP Lite is a Django server-rendered application. PostgreSQL is the database. The iOS app must not connect to it.

`sales/models.py` still describes `Sale` as the invoice header. That comment is stale. `billing/invoice.py` `Invoice` is a separate document.

## Django apps

Verified in `config/settings/base.py` `INSTALLED_APPS` and `config/urls.py`:

| App | Role | Status |
| --- | --- | --- |
| `core` | Shell, login, dashboard, settings, users, language, number sequences | Implemented |
| `audit` | Append-only hash-chained `AuditEvent` | Implemented |
| `clients` | Customers, stored as `Client` | Implemented |
| `vendors` | Suppliers | Implemented |
| `purchases` | Purchase orders, receipts, landed costs | Implemented |
| `inventory` | Physical units and quantity SKU stock | Implemented |
| `sales` | Sale header, lines, SKU ship and cancel | Implemented |
| `payments` | Payments against a whole Sale | Implemented |
| `expenses` | Business expenses and categories | Implemented |
| `assets` | Business assets | Implemented |
| `reports` | HTML reports and CSV exports | Implemented |
| `documents` | Document center plus sale and expense files | Implemented |
| `billing` | Company, billing profiles, tax, invoices, PDF archive | Implemented |

There is no `customers` or `orders` app.

## What changed after `f75a051`

Verified in source, not from commit messages alone:

- `SKUProduct`, `StockBalance`, `StockReservation`, and append-only `StockMovement` (`inventory/sku.py`).
- `ShipmentEvent` for ship, reversal, and logistics cancellation (`inventory/shipments.py`). The file states this is not a financial refund or return.
- `StockCostBalance` and `StockCostEntry` in CAD (`inventory/cost_models.py`). Legacy unit quantities are not converted into SKU stock.
- `PurchaseOrder`, `PurchaseLine`, `GoodsReceipt`, receipt lines, additional costs, and allocations (`purchases/models.py`).
- `Company`, `ClientBillingProfile`, tax codes, `Invoice`, `InvoiceLine`, `InvoiceTaxLine`, logo revisions, and PDF archive (`billing/`).
- `AuditEvent` plus HTML list and detail (`audit/`).
- Sale lines may reference a SKU. Partial line fulfillment is SKU-only. Payment amount due uses an issued invoice grand total when one exists (`billing/ceiling.py`).
- Settings screens for company, tax, users, and English or Simplified Chinese (`core/urls.py`).

## Authentication and authorization

Verified in `config/settings/base.py`, `core/urls.py`, and `core/views.py`.

- `LoginRequiredMiddleware` protects every route except views marked `@login_not_required`.
- Login is `GET/POST /login/` (`ERPLoginView`), an HTML form.
- Logout is POST `/logout/`, CSRF-protected.
- Session cookie is HTTP-only and `SameSite=Lax`. CSRF cookie is HTTP-only.
- Django password validators are enabled. User create, edit, and password screens are HTML under `/settings/users/`.
- There is no token, JWT, or API-key scheme in source.
- Django Admin (`/admin/`) still requires `is_staff`.
- `GET /health/` is public.

The iOS app does not submit the HTML login form.

## HTTP surface

The only `JsonResponse` in the repository is `core/views.py` `health`. Purchasing, SKU, billing, audit, and settings routes render HTML or download a file. See [API_CONTRACT.md](API_CONTRACT.md).

## Business rules that affect the client model

- `InventoryItem` remains one physical unit. Its external number is not a SKU.
- `SKUProduct.identifier` is a UUID and does not use the inventory number sequence. Stock quantities are integers. `available` is `on_hand - reserved`. Direct stock writes are rejected; services own them.
- A sale line links either one inventory unit at quantity 1, or one SKU product, not both. Service lines link neither.
- SKU fulfillment follows shipped quantity: all shipped is delivered, some shipped is partial, none shipped is not delivered. Cancellation reduces remaining quantity and does not count as shipped. Reservation quantity is the remaining quantity.
- `Sale.sale_type` is still derived in `sales/classification.py`: `PRG` → program, `SH` → secondhand, otherwise other. The external invoice number is a sale reference, not `Invoice.invoice_number`.
- Sale total and amount paid are still derived. Amount due is the issued invoice `grand_total` when an issued invoice exists, otherwise the sale total. A void invoice does not set that ceiling.
- Invoice currency is CAD. Drafts are unnumbered. Issued numbers look like `FM-YYMMNNN` (`billing/numbering.py`). `grand_total` must equal `subtotal + tax_total`. Issued and void invoices are frozen. Payments are not allocated per invoice; `Invoice.amount_paid` reads the sale.
- Voiding does not refund or delete payments. There is no refund model. Void is refused when payments exceed the sale total (`billing/issue.py`).
- Purchase orders are `DRAFT`, `OPEN`, or `CANCELLED`. Receipts are `DRAFT`, `POSTED`, or `CANCELLED`. Posted receipt history is retained.
- Client deletion is also blocked by a billing profile. Vendor deletion is blocked by inventory items and purchase orders.
- Company rows are not deleted. At most one company is `is_active`. GST/HST registration is separate from the business number.

## Audit

`audit/models.py` `AuditEvent` is append-only. Application writes go through `audit.services.record_event`. Updates and deletes are rejected. `prev_hash` and `event_hash` support integrity checks. The HTML UI is `/audit/` and `/audit/<pk>/`. That is not a JSON feed.

## Capability summary

| Capability | Classification |
| --- | --- |
| Client, vendor, inventory unit, sale, sale line, payment, expense, asset | Implemented and verified in source |
| Quantity SKU, reservations, shipments, shipment reversal, logistics cancellation | Implemented and verified in source |
| Purchase orders, receiving, landed-cost allocation, SKU cost ledger | Implemented and verified in source |
| Company, client billing profile, tax configuration, invoice draft, issue, void, PDF archive | Implemented and verified in source |
| Append-only audit events | Implemented and verified in source |
| HTML routes for the areas above | Implemented and verified in source |
| `GET /health/` JSON | Implemented and verified in source |
| Dashboard metrics | Implemented as HTML context only |
| Refunds, credit notes, or financial returns | Missing. Void text says a supported refund does not exist yet |
| Customer model distinct from Client | Missing |
| Order model distinct from Sale | Missing |
| JSON API for lists or mutations | Missing |
| Native token or JWT authentication | Missing |
