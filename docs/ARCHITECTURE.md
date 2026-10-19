# Architecture

ERP Lite iOS is a SwiftUI client. The Django ERP Lite application, in a separate repository, owns business rules, stored records, authorization, and audit trails. This app does not duplicate that system and does not assume the backend already exposes a REST API.

Phase 0 prepares seams for a later contract. Screens that show information label it as mock data. The networking stack can build a request, but the running app does not send one.

## Inspection before this phase

The repository started as an Xcode 26.5 SwiftUI app:

- Entry point: `ERPLITEIOSApp`
- Interface: `ContentView`, the template "Hello, world!" screen, now removed
- Project: `ERPLITEIOS/ERPLITEIOS.xcodeproj`, object version 77, file-system synchronized source group
- Deployment target: iOS 26.5, iPhone and iPad
- Bundle identifier: `com.flowmagik.ERPLITEIOS`
- Swift: 5 language mode, default actor isolation MainActor, approachable concurrency enabled
- Tests: none
- Dependencies: none
- Git: `main` tracking `origin/main`, no `.gitignore`

New Swift files under `ERPLITEIOS/ERPLITEIOS/` are picked up by the synchronized group. The unit and UI test targets are registered in the project because they live outside that folder.

## Layout

```
ERPLITEIOS/ERPLITEIOS/
  App/             Entry composition, app phase, root navigation
  Core/
    Configuration/ Base URL, version prefix, timeout
    Networking/    URLSession client, errors, JSON, URL joining
    Security/      Keychain and in-memory credential stores
  Models/          Client session and data-origin labels
  Features/
    Auth/          Placeholder sign-in
    Dashboard/     Placeholder home
  Services/        Mock authentication
  DesignSystem/    Theme, mock banner, loading and error states
  Resources/       Empty backend settings and the English string catalog
```

`AppDependencies` is the composition root. The live app uses the keychain, a mock auth service, and a `URLSession` client whose authorizer refuses to attach credentials. Previews and tests substitute the in-memory store and a controllable clock.

## Concurrency

The app target isolates code to the main actor by default. `URLSession.data(for:)` still suspends, so a request does not block the interface while it is in flight. Feature state that SwiftUI observes (`AppModel`, `LoginViewModel`) stays on that actor. Tests that touch these types run on the main actor as well.

## Navigation

`AppModel.phase` decides whether the login screen or the signed-in shell is visible:

| Phase | Screen |
| --- | --- |
| `launching` | Loading |
| `signedOut` | Login |
| `sessionExpired` | Login, with an expiry notice |
| `authenticated` | Tab shell |
| `failed` | Error, with retry. A storage failure can also continue to mock sign-in |

The signed-in shell is a `TabView` with Dashboard, Inventory, Sales, Invoices, Clients, and Settings. Each tab has its own `NavigationStack`, so a detail screen on one tab does not replace the others. Search text and filters live on the list view models. Leaving a detail screen does not reload a list that has already loaded. A second `.task` pass does not clear that search.

`AppShellState` holds the selected tab. Sign-out, session expiry, and discarding a saved session call `reset()`, which returns to Dashboard and bumps a generation value. The shell view uses that generation as its identity, so the next sign-in does not restore the previous tab, search, or detail stack. A cold launch that finds no session does not reset the shell.

Returning to the foreground re-checks an authenticated mock session and moves to the expiry screen when its local deadline has passed. That path also resets the shell.

## Networking

`URLSessionHTTPClient` builds an absolute URL from:

1. The configured base URL
2. An optional version prefix such as `api/v1`, only when a developer sets one
3. The relative path on that call

There is no catalog of ERP Lite paths. Callers will add paths when a contract exists. The client:

- Does not send when the base URL is missing
- Times out from the configured request timeout
- Maps timeouts, cancellation, offline, unreachable host, TLS or App Transport Security failures, non-HTTP responses, HTTP 401, and other status codes into `APIError`
- Uses those names in the UI. It does not pass through the system error text, the host, or response bodies
- Sends a `GET` one extra time after a timeout, an offline error, or an unreachable host. `POST` and other methods are not retried. HTTP error statuses are not retried. A cancelled call is not retried
- Does not keep response bodies on errors
- Uses an ephemeral session with cookies disabled, so it does not grow an implied Django session
- Does not follow redirects
- Omits `Authorization`, `Cookie`, and `Set-Cookie` from the header map returned to callers
- Calls `RequestAuthorizing` only when a request opts in

`PendingContractAuthorizer` is the live authorizer. It throws `authenticationSchemeNotConfigured` and does not guess Bearer tokens, session cookies, or CSRF.

JSON encoding uses ISO-8601 dates and does not rewrite keys. That choice is provisional.

## Authentication

`AuthServicing` is the seam a real ERP Lite login will implement later. `MockAuthService` is the only implementation today.

- Any non-empty username and password are accepted
- The password is not stored, logged, or sent
- A `mock-session-` marker is saved in the keychain with an 8-hour local expiry
- That lifetime is a client placeholder, not a backend policy
- Expiry clears the marker and surfaces `sessionExpired`
- Logout clears the marker

`TokenStoring` hides the keychain. Tests use `InMemoryTokenStore`. The keychain item is a generic password under `com.flowmagik.ERPLITEIOS.session`, available only while this device is unlocked, and it is not synced. Replacing a saved marker updates that item in place.

## Mock versus backend data

`DataOrigin.mock` marks sample inventory, SKU balances, clients, sales, and invoices. A health report decoded from `GET /health/` is `DataOrigin.backend`. `AppConfiguration.contractIntegrated` stays false because list screens are not a live API.

Phase 1A records the Django models and the HTML-versus-JSON split in [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md), [DATA_MODELS.md](DATA_MODELS.md), and [API_CONTRACT.md](API_CONTRACT.md).

## Read cache

`ReadCachePolicy.bypass` is what `MockERPReader` uses. It does not write sample clients, inventory, sales, invoices, or payments anywhere.

`ReadCachePolicy.memoryOnly(freshFor:)` is the opt-in for a future backend reader. `ProtectedMemoryCache` keeps values in process memory, stamped with the account label and the time they were stored. A value is stale when its age reaches `freshFor`. A load for a different account label does not return the stored value. Sign-out and session expiry call `invalidateAll()`.

Nothing in this cache is written to UserDefaults, the keychain, or a file. Do not put ERP business rows on disk until a later phase defines retention and encryption. The development base URL in Settings is not part of this cache. It is only a URL.

A health result shown in Settings is cleared when that URL is saved or cleared, including while a check is still in flight. The check remains `GET /health/` and does not enable business lists.

## Scanning and unsent drafts

Phase 1D adds a Scan action on the Dashboard. Recognition, lookup, and draft editing are separate. The camera path uses VisionKit `DataScannerViewController` when the device supports it. The Simulator does not. Manual entry is the complete alternative and is what tests use.

Lookup compares the raw code with sample SKU codes, inventory numbers, external inventory numbers, and asset numbers. It does not call the network. A miss against the sample catalog is labeled as a mock miss. Drafts stay in `IntakeDraftStore` and are discarded on sign-out, session expiry, and explicit cancel. Photos attached to a draft are in-memory JPEG data, not files and not uploads.

The verified Django gap and the proposed future API are in [SCANNING_AND_INTAKE.md](SCANNING_AND_INTAKE.md) and [MOBILE_API_REQUIREMENTS.md](MOBILE_API_REQUIREMENTS.md).

## What remains out of scope

- Live list and mutation calls. Those JSON routes do not exist in the inspected backend
- Posting the Django HTML login form
- Third-party packages
- Certificate pinning, refresh-token rotation, and company or tenant selection
- Any hardcoded host, token, or password
