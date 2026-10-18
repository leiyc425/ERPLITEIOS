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

`AppModel.phase` is the navigation state:

| Phase | Screen |
| --- | --- |
| `launching` | Loading |
| `signedOut` | Login |
| `sessionExpired` | Login, with an expiry notice |
| `authenticated` | Dashboard inside a `NavigationStack` |
| `failed` | Error, with retry. A storage failure can also continue to mock sign-in |

Returning to the foreground re-checks an authenticated mock session and moves to the expiry screen when its local deadline has passed.

## Networking

`URLSessionHTTPClient` builds an absolute URL from:

1. The configured base URL
2. An optional version prefix such as `api/v1`, only when a developer sets one
3. The relative path on that call

There is no catalog of ERP Lite paths. Callers will add paths when a contract exists. The client:

- Does not send when the base URL is missing
- Times out from the configured request timeout
- Maps `URLError.timedOut`, cancellation, non-HTTP responses, HTTP 401, and other status codes into `APIError`
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

`DataOrigin.mock` marks sample inventory, clients, and sales. A health report decoded from `GET /health/` is `DataOrigin.backend`. `AppConfiguration.contractIntegrated` stays false because list screens are not a live API.

Phase 1A records the Django models and the HTML-versus-JSON split in [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md), [DATA_MODELS.md](DATA_MODELS.md), and [API_CONTRACT.md](API_CONTRACT.md).

## What remains out of scope

- Live list and mutation calls. Those JSON routes do not exist in the inspected backend
- Posting the Django HTML login form
- Third-party packages
- Certificate pinning, refresh-token rotation, and company or tenant selection
- Any hardcoded host, token, or password
