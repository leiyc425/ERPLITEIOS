# Data models

Source: ERP Lite commit `f75a051`. Types below are the database models. They are not JSON response schemas.

Money fields are `Decimal` with 2 CAD places unless noted. Identifiers such as `client_number` are text so leading zeros survive.

## Client

`clients/models.py` `Client`.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | integer primary key | |
| `client_number` | string, max 64 | Unique case-insensitively. System-generated when blank on create |
| `client_type` | `COMPANY` or `INDIVIDUAL` | Default `COMPANY` |
| `name` | string, max 255 | Required |
| `notes` | text | Optional |
| `is_active` | boolean | Default true |
| `created_at`, `updated_at` | datetime | |

Relationships: `sales` and `business_expenses` use `PROTECT`. `can_be_deleted()` is false when either exists.

There is no email, phone, or address field on this model.

## InventoryItem

`inventory/models.py` `InventoryItem`. One physical resale unit.

| Field | Type | Notes |
| --- | --- | --- |
| `inventory_number` | string, max 64 | Unique case-insensitively. System-generated when blank on create |
| `external_inventory_number` | string, max 64 | Optional. Not a shared SKU. Unique when non-blank |
| `name` | string, max 255 | Required |
| `specification` | text | Optional |
| `acquired_date` | date | Required |
| `purchase_cost` | decimal(12,2) | CAD, minimum 0 |
| `status` | `IN_STOCK`, `RESERVED`, `SOLD` | Default `IN_STOCK` |
| `purchase_source` | string, max 255 | Channel text, not a vendor |
| `vendor` | FK `vendors.Vendor`, null | `PROTECT` |
| `transaction_number` | string, max 128 | Optional |
| `notes` | text | Optional |

`sale_line` is the reverse one-to-one from `SaleLine.inventory_item`. Deletion is refused when a sale line points at the item.

## Vendor

`vendors/models.py` `Vendor`: `name` (unique case-insensitively), `notes`, `is_active`, timestamps. Not a Phase 1A screen. Inventory samples may show the vendor name.

## Sale

`sales/models.py` `Sale`. This is the invoice and the sales transaction. It is not a separate order.

| Field | Type | Notes |
| --- | --- | --- |
| `sale_number` | string, max 64 | Unique case-insensitively. System-generated when blank |
| `external_invoice_number` | string, max 64 | Optional. Unique when non-blank |
| `sale_type` | `PROGRAM`, `SECONDHAND`, `OTHER` | Written from the external invoice prefix |
| `client` | FK `Client` | Required, `PROTECT` |
| `sale_date` | date | Required |
| `notes` | text | Optional |

Derived, not columns:

| Property | Rule |
| --- | --- |
| `total` | Sum of line quantity × unit price, 2 decimal places |
| `fulfillment_status` | No lines or none delivered → `NOT_DELIVERED`. All delivered → `DELIVERED`. Otherwise `PARTIALLY_DELIVERED` |
| `amount_paid` | Sum of `Payment.amount` |
| `outstanding_balance` | `total - amount_paid` |
| `payment_status` | Total ≤ 0 → `PAID` with label "No Balance Due". Paid ≤ 0 → `UNPAID`. Paid below total → `PARTIALLY_PAID`. Else `PAID` |

`can_be_deleted()` is false when any payment, expense, document, or delivered line exists.

## SaleLine

`sales/models.py` `SaleLine`.

| Field | Type | Notes |
| --- | --- | --- |
| `sale` | FK `Sale` | `CASCADE` |
| `line_number` | positive integer | Unique per sale. Allocated when omitted |
| `line_type` | `PRODUCT` or `SERVICE` | |
| `item_code` | string, max 64 | Optional. Not unique |
| `name` | string, max 255 | Required |
| `description` | text | Optional |
| `quantity` | positive integer | Minimum 1. Must be 1 when an inventory item is linked |
| `unit_price` | decimal(12,2) | CAD, minimum 0 |
| `inventory_item` | one-to-one `InventoryItem`, null | Product lines only. `PROTECT` |
| `fulfillment_status` | `NOT_DELIVERED` or `DELIVERED` | |
| `fulfilled_date` | date, null | Required when delivered. Cleared otherwise |
| `notes` | text | Optional |

`line_total` is quantity × unit price. A change that would drop the sale total below amount paid is rejected. Delivered lines cannot be deleted until fulfillment is reversed. Deleting a line returns linked inventory to `IN_STOCK` when it was not already in stock (`SaleLine.delete`).

## Payment

`payments/models.py` `Payment`. One row is a receipt against the whole sale.

| Field | Type | Notes |
| --- | --- | --- |
| `sale` | FK `Sale` | `PROTECT` |
| `payment_date` | date | |
| `amount` | decimal(12,2) | CAD, greater than 0. This is the amount applied to the sale |
| `original_currency` | string, 3 | Default `CAD` |
| `original_amount` | decimal(12,2) | Greater than 0 |
| `fx_rate` | decimal(18,8), null | CAD per 1 unit of original currency. Required for non-CAD |
| `payment_method` | string, max 64 | Optional |
| `reference` | string, max 128 | Optional |
| `notes` | text | Optional |

Overpayment is rejected in `payments/services.py`. The iOS sample data does not create payments.

## NumberSequence

`core/models.py`. Internal counter (`key`, `next_value`). Not a business screen.

## Not in the database

Verified by the absence of models, not by assumption:

- Customer distinct from Client
- Order distinct from Sale
- Invoice distinct from Sale
- Product or SKU catalog
- Company profile or settings
- A general audit-event table
