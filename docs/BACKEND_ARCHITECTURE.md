# Backend architecture

Inspected read-only from `/Users/yclei/Desktop/ERPLITE` at commit `f75a051` (`main`, tracking `origin/main`, clean working tree at inspection). Later unpushed work in that checkout is not included. No backend file was modified.

ERP Lite v0.3.0 is a Django server-rendered application. PostgreSQL is the database. The iOS app must not connect to it.

## Django apps

Verified in `config/settings/base.py` `INSTALLED_APPS` and `config/urls.py`:

| App | Role | Status |
| --- | --- | --- |
| `core` | Shell, login, dashboard, number sequences | Implemented |
| `clients` | Customers, stored as `Client` | Implemented |
| `vendors` | Suppliers | Implemented |
| `inventory` | Physical resale units | Implemented |
| `sales` | Sale header and lines. The header is the invoice | Implemented |
| `payments` | Payments against a whole Sale | Implemented |
| `expenses` | Business expenses and categories | Implemented |
| `assets` | Business assets | Implemented |
| `reports` | HTML reports and CSV exports | Implemented |
| `documents` | Private file attachments on sales and expenses | Implemented |

There is no `customers`, `orders`, `invoices`, `products`, or `company` app.

## Authentication and authorization

Verified in `config/settings/base.py`, `core/urls.py`, `core/views.py`, and `core/tests/test_auth.py`.

- `LoginRequiredMiddleware` protects every route except views marked `@login_not_required`.
- Login is `GET/POST /login/` (`ERPLoginView`), an HTML form. Redirects authenticated users to the dashboard.
- Logout is POST `/logout/`, CSRF-protected (`ERPLogoutView`).
- Session cookie is HTTP-only and `SameSite=Lax`. CSRF cookie is HTTP-only.
- Django password validators are enabled. There is no token, JWT, or API-key scheme in source.
- Django Admin (`/admin/`) still requires `is_staff`.
- `GET /health/` is public.

The iOS app does not submit the HTML login form. Doing so would require cookies and CSRF, which the Phase 0 client deliberately does not store.

## HTTP surface

`config/urls.py` mounts HTML apps. The only `JsonResponse` in the repository is `core/views.py` `health`.

| Route | Kind | Auth | Status |
| --- | --- | --- | --- |
| `GET /health/` | JSON | Public | Implemented |
| `GET/POST /login/` | HTML form | Public | Implemented |
| `POST /logout/` | HTML, CSRF | Session | Implemented |
| `GET /` | HTML dashboard | Session | Implemented |
| `/clients/`, `/inventory/`, `/sales/`, `/payments/`, `/vendors/`, `/expenses/`, `/assets/`, `/reports/` | HTML | Session | Implemented |
| Machine-readable list or mutation API | — | — | Missing |

A Django model does not imply a REST resource. CSV report downloads are file responses for a logged-in browser, not a mobile API.

## Dashboard

`core/dashboard.py` `build_dashboard_context` builds template context, not a JSON document. Verified metric groups include sales, expenses, payments, current inventory counts (`in_stock`, `reserved`, `sold`, `on_hand_value`), assets, net operating profit, charts, recent sales, recent expenses, and upcoming planned expenses. The iOS dashboard does not recompute profit. Those figures stay on the server until a JSON contract exists.

## Business rules that affect the client model

- Inventory is one physical unit per `InventoryItem`, not a shared SKU. `inventory/models.py` says the external number is not a SKU.
- `Sale` is the invoice header (`sales/models.py` docstring). There is no separate invoice or order table.
- `Sale.sale_type` is derived from the external invoice prefix in `sales/classification.py`: `PRG` → program, `SH` → secondhand, otherwise other.
- Sale total, fulfillment, amount paid, outstanding balance, and payment status are derived. They are not stored columns.
- A product line may link one inventory unit with quantity 1. Service lines cannot link inventory.
- Payments belong to the sale, not a line. Currency of record for `amount` is CAD. Foreign payments also store original currency, original amount, and FX rate (`payments/models.py`).
- Number sequences in `core/numbering.py` allocate zero-padded identifiers (`0001`, …) and do not reuse deleted numbers.
- Fulfillment and payment changes go through `sales/services.py` and `payments/services.py` inside `transaction.atomic`.
- Clients and vendors with dependent rows cannot be deleted (`on_delete=PROTECT`). Inactive is the alternative for clients.

## Audit and company settings

- Rows store `created_at` and `updated_at`. There is no general audit-log model.
- `documents/integrity.py` and `core/full_backup.py` audit private files against document rows. That is an operator command, not a user-facing audit API.
- No company-settings model was found.

## Capability summary

| Capability | Classification |
| --- | --- |
| Client, vendor, inventory unit, sale, sale line, payment, expense, asset models | Implemented and verified in source |
| HTML CRUD for those areas | Implemented and verified in source |
| Derived sale total, fulfillment, and payment status | Implemented and verified in source |
| Session login and login-required middleware | Implemented and verified in source |
| `GET /health/` JSON | Implemented and verified in source |
| Dashboard metrics | Implemented as HTML context only |
| Shared SKU / product catalog | Missing. Explicitly rejected by the inventory model text |
| Customer model distinct from Client | Missing |
| Order model distinct from Sale | Missing |
| Invoice model distinct from Sale | Missing |
| Company settings | Missing |
| General audit log API | Missing |
| JSON API for lists or mutations | Missing |
