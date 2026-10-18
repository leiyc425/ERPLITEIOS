# Data models

Source: ERP Lite commit `cf141a1` on `dev`. Types below are database models. They are not JSON response schemas.

The previous audit (`f75a051`) treated `Sale` as the invoice and reported no SKU, company, or audit table. Those statements are no longer true. `sales/models.py` still says the sale is the invoice header; `billing.Invoice` is the document.

Money on sales and payments is `Decimal` with 2 CAD places unless noted. SKU cost fields use more places and are not copied into the iOS samples. Identifiers such as `client_number` are text so leading zeros survive.

## Client

`clients/models.py` `Client`. Fields are unchanged: `client_number`, `client_type` (`COMPANY` or `INDIVIDUAL`), `name`, `notes`, `is_active`, timestamps. There is still no email, phone, or address on this model.

`can_be_deleted()` is false when sales, expenses, or billing profiles exist. Billing identity lives on `ClientBillingProfile`.

## InventoryItem

`inventory/models.py` `InventoryItem`. Still one physical resale unit.

| Field | Type | Notes |
| --- | --- | --- |
| `inventory_number` | string, max 64 | Unique case-insensitively |
| `external_inventory_number` | string, max 64 | Optional. Not a shared SKU |
| `name` | string, max 255 | Required |
| `specification` | text | Optional |
| `acquired_date` | date | Required |
| `purchase_cost` | decimal(12,2) | CAD, minimum 0 |
| `status` | `IN_STOCK`, `RESERVED`, `SOLD` | Default `IN_STOCK` |
| `purchase_source` | string, max 255 | Channel text |
| `vendor` | FK `Vendor`, null | `PROTECT` |
| `transaction_number` | string, max 128 | Optional |
| `notes` | text | Optional |

Deletion is refused when a sale line points at the item.

## SKUProduct and stock

`inventory/sku.py`. Separate from `InventoryItem`.

| Model | Fields that matter | Notes |
| --- | --- | --- |
| `SKUProduct` | `identifier` UUID, `sku`, `name`, `description`, `is_active` | `sku` unique case-insensitively. Not the inventory number sequence |
| `StockBalance` | `on_hand`, `reserved` integers | `reserved` cannot exceed `on_hand`. `available` is `on_hand - reserved` |
| `StockReservation` | sale line, sale number, line number, `quantity` | Current allocation. Released rows can remain at quantity 0 |
| `StockMovement` | `RECEIPT`, `ADJUSTMENT`, `SHIPMENT`, `SHIPMENT_REVERSAL` | Append-only. Non-zero delta |

`inventory/shipments.py` `ShipmentEvent`: `SHIPMENT`, `REVERSAL`, `CANCELLATION`. Positive quantity. Not a refund.

`inventory/cost_models.py` stores CAD valuation separately (`value_cad` up to 8 decimal places). Unknown opening cost stays null until confirmed. The iOS client does not recompute COGS.

## Vendor

`vendors/models.py` `Vendor`: `name`, `notes`, `is_active`. Deletion fails when inventory items or purchase orders exist, and also fails closed if the purchase table is absent.

## Sale

`sales/models.py` `Sale`. The business transaction. Not an order table and not the billing invoice.

| Field | Type | Notes |
| --- | --- | --- |
| `sale_number` | string, max 64 | Unique case-insensitively |
| `external_invoice_number` | string, max 64 | Optional sale reference such as `SH004` or `PRG001` |
| `sale_type` | `PROGRAM`, `SECONDHAND`, `OTHER` | Written from that reference prefix |
| `client` | FK `Client` | `PROTECT`. Cannot change after an issued invoice |
| `sale_date` | date | Required |
| `notes` | text | Optional |

Derived:

| Property | Rule |
| --- | --- |
| `total` | Sum of line quantity × unit price, 2 decimal places |
| `fulfillment_status` | No lines, or none delivered and none partial → `NOT_DELIVERED`. All delivered → `DELIVERED`. Otherwise `PARTIALLY_DELIVERED` |
| `amount_paid` | Sum of `Payment.amount` |
| `amount_due` | Issued invoice `grand_total`, otherwise `total` (`billing/ceiling.py`) |
| `outstanding_balance` | `amount_due - amount_paid` |
| `payment_status` | Amount due ≤ 0 → `PAID`, label "No Balance Due". Paid ≤ 0 → `UNPAID`. Paid below amount due → `PARTIALLY_PAID`. Else `PAID` |

An issued invoice also blocks changing `sale_number`.

## SaleLine

| Field | Type | Notes |
| --- | --- | --- |
| `line_type` | `PRODUCT` or `SERVICE` | |
| `quantity` | positive integer | Minimum 1. Must be 1 when an inventory item is linked |
| `unit_price` | decimal(12,2) | CAD, minimum 0 |
| `inventory_item` | one-to-one, null | Product only. Mutually exclusive with a SKU |
| `sku_product` | FK `SKUProduct`, null | Product only |
| `shipped_quantity`, `cancelled_quantity` | non-negative integers | SKU lines only. Quantity must cover both |
| `fulfillment_status` | `NOT_DELIVERED`, `PARTIALLY_DELIVERED`, `DELIVERED` | Partial is rejected unless the line is a SKU |
| `fulfilled_date` | date, null | Required when delivered |

SKU fulfillment is derived from `shipped_quantity` versus `quantity`. `remaining_quantity` is quantity minus shipped minus cancelled. Reservation quantity must match that remainder before a shipment posts.

## Payment

`payments/models.py` `Payment`. Unchanged shape: CAD `amount` against the whole sale, plus original currency, original amount, and FX rate. There is no refund row. Saving a payment locks the sale.

## Invoice

`billing/invoice.py`.

| Field | Type | Notes |
| --- | --- | --- |
| `sale`, `company`, `client`, `billing_profile` | FKs | Client must match the sale |
| `status` | `DRAFT`, `ISSUED`, `VOID` | One draft or issued invoice per sale |
| `invoice_number` | string, null | Null on drafts. Unique. Format `FM-YYMMNNN` at issue |
| `currency` | string | Constrained to `CAD` |
| `subtotal`, `tax_total`, `grand_total` | decimal(14,2) | Non-negative. Grand total equals subtotal plus tax |
| `issue_date`, snapshots | | Required once issued or void. Frozen afterward |

`amount_paid` is the sale's amount paid. `balance_due` is grand total minus that amount, and only while status is `ISSUED`. Other statuses return no balance due.

`InvoiceLine` copies a sale line and stores `line_net`, `tax_total`, `gross`, and optional frozen `source_sku_code`. `display_item_code` does not read the live SKU. `InvoiceTaxLine` stores each rounded component. The iOS samples show the stored totals and do not run `billing/tax.py`.

## Company and tax

`billing/models.py` `Company`: legal name, trade name, address, country code, phone, email, website, business number, `gst_hst_registered`, `gst_hst_number`, `default_billing_currency`, `is_active`. At most one active company. Rows are not deleted.

`ClientBillingProfile` is the customer billing identity for a client and company. Profiles are deactivated, not deleted.

`billing/tax_config.py`: `TaxCode`, `TaxCodeVersion`, `TaxComponent`. Treatments are `STANDARD`, `ZERO_RATED`, `EXEMPT`, `OUT_OF_SCOPE`. Address does not select the code. The tax engine is server-side.

## Purchase

`purchases/models.py`.

| Model | Status or amounts | Notes |
| --- | --- | --- |
| `PurchaseOrder` | `DRAFT`, `OPEN`, `CANCELLED` | Supplier is a `Vendor`. Currency is a 3-letter code, default `CAD` |
| `PurchaseLine` | `ordered_quantity`, `unit_price`, `unit_discount` | Prices use 8 decimal places. Net unit price is price minus discount |
| `GoodsReceipt` | `DRAFT`, `POSTED`, `CANCELLED` | `fx_rate` must be positive |
| `GoodsReceiptLine` | quantity and CAD goods amount | One stock movement when posted |
| `PurchaseAdditionalCost` | freight, duty, brokerage, other, tax | Treatment and allocation method are stored. Tax treatment needs an explicit review |
| `PurchaseCostAllocation` | original and CAD amounts | Insert-only |

## AuditEvent

`audit/models.py`. `occurred_at`, actor, `actor_username`, `action`, `object_type`, `object_pk`, `request_id`, `ip_address`, `reason`, `payload`, `prev_hash`, `event_hash`. Append-only.

## Not in the database

- Customer distinct from Client
- Order distinct from Sale
- A refund, credit note, or financial return model
- A JSON serializer for these rows
