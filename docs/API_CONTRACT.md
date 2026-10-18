# API contract

Source: ERP Lite commit `cf141a1` on `dev`. This file records routes that exist. It does not add any.

## Machine-readable

### `GET /health/`

Verified in `core/urls.py` and `core/views.py` (`health`).

- Method: `GET` only (`require_GET`)
- Auth: public (`@login_not_required`)
- Success body: `{"status": "ok", "database": "ok"}` with HTTP 200
- Database failure: `{"status": "degraded", "database": "error"}` with HTTP 503
- No secrets, settings, or business rows
- Django's trailing slash is part of the route. The iOS client requests `/health/` and does not follow a redirect to add the slash
- This path is at the site root. It ignores `ERPLITE_API_VERSION_PREFIX`

The iOS `LiveHealthCheck` calls this only when `ERPLITE_API_BASE_URL` is set. With an empty base URL it does not send the request.

No other `JsonResponse`, DRF view, or serializer was found at `cf141a1`. SKU, purchasing, billing, and audit routes are not JSON.

## Browser routes (not a mobile API)

These return HTML, a PDF, or a CSV for a logged-in browser. Calling them from the app would not yield the models in `DATA_MODELS.md`.

Authentication is the Django session cookie. Mutations are form posts with CSRF. Logout is POST-only.

| Prefix | Examples | Source |
| --- | --- | --- |
| `/login/`, `/logout/` | Session form | `core/urls.py` |
| `/` | Dashboard | `core/urls.py` |
| `/settings/` | Overview, language, users, tax | `core/urls.py` |
| `/clients/` | list, create, edit, delete | `clients/urls.py` |
| `/vendors/` | HTML CRUD | `vendors/urls.py` |
| `/inventory/` | Unit CRUD | `inventory/urls.py` |
| `/inventory/sku/` | SKU list, create, detail, receive, adjust | `inventory/urls.py` |
| `/purchases/` | Orders, receipts, costs, documents | `purchases/urls.py` |
| `/sales/` | Sale CRUD, lines, ship, cancel, reverse, payments, documents | `sales/urls.py` |
| `/payments/` | list | `payments/urls.py` |
| `/billing/` | Company, billing profile, invoice draft, issue, void, PDF | `billing/urls.py` |
| `/audit/` | Event list and detail | `audit/urls.py` |
| `/documents/` | Document center | `documents/urls.py` |
| `/expenses/`, `/assets/` | HTML CRUD | matching `urls.py` |
| `/reports/` | HTML reports, CSV exports, SKU cost reports | `reports/urls.py` |

`LoginRequiredMiddleware` redirects anonymous browser requests to login. The iOS client does not follow those redirects and does not attach a session.

## What the iOS app implements against this contract

| Screen | Data source |
| --- | --- |
| Health check button | Live `GET /health/` only when a base URL is configured. Otherwise no request |
| Inventory | Mock physical units and one mock SKU balance. `DataOrigin.mock` |
| Clients, Sales | Mock samples. `DataOrigin.mock` |
| Invoices | Mock `Invoice` rows with stored totals. Not a second view of `Sale` |
| Sign-in | Phase 0 on-device mock. It does not POST `/login/` |

The client does not call receive, adjust, ship, issue, void, or PDF routes.

## Missing contract (required before live lists)

The backend does not provide these. They are requirements, not existing routes:

1. A versioned JSON API, or an explicit decision to keep the mobile client on mocks.
2. An authentication scheme for native clients. Session cookie plus CSRF is what the HTML app uses. It is not implemented here.
3. List and detail representations for `Client`, `InventoryItem`, `SKUProduct` with balances, `Sale`, and `Invoice`.
4. Error envelope and permission failures distinct from an HTML login redirect.
5. Pagination and filtering, if the HTML list behavior is to be matched.
6. Confirmation that create, receive, ship, pay, issue, void, and delete stay server-side. The iOS screens do not perform those operations.

Do not point list screens at the HTML paths above to fill this gap.
