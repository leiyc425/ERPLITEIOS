# API contract

Source: ERP Lite commit `f75a051`. This file records routes that exist. It does not add any.

## Machine-readable

### `GET /health/`

Verified in `core/urls.py` and `core/views.py` (`health`).

- Method: `GET` only (`require_GET`)
- Auth: public (`@login_not_required`)
- Success body: `{"status": "ok", "database": "ok"}` with HTTP 200
- Database failure: `{"status": "degraded", "database": "error"}` with HTTP 503
- No secrets, settings, or business rows
- Django's trailing slash is part of the route. The iOS client requests `/health/` and does not follow a redirect to add the slash
- This path is at the site root. It is not under `/api/` and it ignores `ERPLITE_API_VERSION_PREFIX`

The iOS `LiveHealthCheck` calls this only when `ERPLITE_API_BASE_URL` is set. With an empty base URL it does not send the request.

No other `JsonResponse`, DRF view, or serializer was found.

## Browser routes (not a mobile API)

These return HTML or, for report exports, CSV for a logged-in browser. Calling them from the app would not yield the models in `DATA_MODELS.md`.

Authentication for all of them except login is the Django session cookie. Mutations are form posts with CSRF. Logout is POST-only.

| Prefix | Examples | Source |
| --- | --- | --- |
| `/login/`, `/logout/` | Session form | `core/urls.py` |
| `/` | Dashboard | `core/urls.py` |
| `/clients/` | list, `new/`, `<pk>/`, `edit/`, `delete/` | `clients/urls.py` |
| `/inventory/` | same shape | `inventory/urls.py` |
| `/sales/` | sale CRUD, lines, payments, documents | `sales/urls.py` |
| `/payments/` | list only | `payments/urls.py` |
| `/vendors/`, `/expenses/`, `/assets/` | HTML CRUD | matching `urls.py` |
| `/reports/` | HTML reports and `export.csv` | `reports/urls.py` |

`LoginRequiredMiddleware` redirects anonymous browser requests to login. The iOS client does not follow those redirects and does not attach a session.

## What the iOS app implements against this contract

| Screen | Data source |
| --- | --- |
| Health check button | Live `GET /health/` only when a base URL is configured. Otherwise no request |
| Inventory, Clients, Sales, Invoices | Mock samples whose fields and derived totals follow the models. `DataOrigin.mock` |
| Sign-in | Still the Phase 0 on-device mock. It does not POST `/login/` |

Invoices are a view of `Sale`, including `external_invoice_number` and derived payment status. They are not a second endpoint.

## Missing contract (required before live lists)

The backend does not provide these. They are requirements, not existing routes:

1. A versioned JSON API, or an explicit decision to keep the mobile client on mocks.
2. An authentication scheme for native clients. Session cookie plus CSRF is what the HTML app uses. It is not implemented here.
3. List and detail representations for `Client`, `InventoryItem`, and `Sale` (with lines, derived totals, and payments).
4. Error envelope and permission failures distinct from an HTML login redirect.
5. Pagination and filtering, if the HTML list behavior is to be matched.
6. Confirmation that create, update, fulfill, pay, and delete stay server-side. The iOS screens do not perform those operations.

Do not point list screens at the HTML paths above to fill this gap.
