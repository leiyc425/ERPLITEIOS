# Development

## Requirements

- macOS with Xcode 26.5
- iOS 26.5 simulator
- Initial device: iPhone 17 Pro
- No package manager dependencies

Open `ERPLITEIOS/ERPLITEIOS.xcodeproj`. The shared scheme is `ERPLITEIOS`.

Work continues on the `dev` branch. `main` stays as the initial SwiftUI project until a change is ready to merge.

## Build and test

From the repository root:

```sh
xcodebuild \
  -project ERPLITEIOS/ERPLITEIOS.xcodeproj \
  -scheme ERPLITEIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Unit tests cover configuration, URL joining, the HTTP client (against an in-process `URLProtocol` stub), mock sign-in, session expiry, and the keychain store. `AppFlowUITests` signs in with mock credentials, checks the mock banner, and signs out.

A build for the simulator without tests:

```sh
xcodebuild \
  -project ERPLITEIOS/ERPLITEIOS.xcodeproj \
  -scheme ERPLITEIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Run the shell

The app opens on a mock sign-in screen. Any non-empty username and password is accepted on the device. The password is not sent anywhere. The dashboard lists Inventory, Orders, and Customers as placeholders and labels them MOCK.

Launch arguments:

- `--reset-session` clears the stored mock marker before the first restore. UI tests set this so a previous keychain item cannot skip the login screen.

## Backend URL

Do not put a host, token, or password in the repository. `ERPLITEIOS/ERPLITEIOS/Resources/BackendConfiguration.json` ships with an empty `baseURL` and an empty `apiVersionPrefix`. Leave it that way.

When a contract exists, set these for the simulator scheme or the test process. They override the bundled file. An empty value clears the bundled value.

| Variable | Meaning |
| --- | --- |
| `ERPLITE_API_BASE_URL` | `http` or `https` URL with no username, password, query, or fragment |
| `ERPLITE_API_VERSION_PREFIX` | Optional path prefix, for example `api/v1`, once the backend defines one |
| `ERPLITE_API_TIMEOUT_SECONDS` | Whole or fractional seconds from 1 through 180 |

A saved URL still does not make the app call ERP Lite. Phase 0 has no routes to call. An invalid URL fails launch with a configuration error instead of silently falling back.

Plain `http` is rejected by App Transport Security until a later change adds a specific local exception. Do not turn on arbitrary loads to get there.

## Project settings that should stay put

The generated project already targets iOS 26.5, uses a synchronized source group, and isolates the app to the main actor. New app sources do not need `project.pbxproj` edits. Test targets do, because they are separate bundles.

## Git hygiene

`.gitignore` excludes Xcode user data, `DerivedData`, and build products. Do not commit:

- `xcuserdata`
- simulator or device build output
- tokens, passwords, `.env` files, or a filled-in base URL
- a private LAN address

The configuration unit test reads `BackendConfiguration.json` from the repo and fails if a URL is committed.
