# API integration

The iOS app is a client of ERP Lite. It is not a second implementation of the ERP.

The verified HTTP surface is documented in [API_CONTRACT.md](API_CONTRACT.md). The only JSON route found in ERP Lite commit `cf141a1` is `GET /health/`. Business screens in that checkout are HTML. This client does not invent list endpoints for them.

## What is blocked

These have to be answered from the backend repository, or from an agreed contract, before live calls are added:

1. Whether ERP Lite exposes an HTTP API at all, and which base path it uses.
2. The authentication scheme. Candidates that must not be assumed include Django session cookies and CSRF, a DRF-style token, JWT, or SSO. The live authorizer fails closed until one is specified.
3. How sessions expire, refresh, and revoke, and which error means "sign in again."
4. The resource list for the first mobile workflows, including field names, pagination, and the error envelope.
5. How API versions are expressed: path prefix, header, or something else. The client can insert a path prefix. It does not default to one.
6. The environment host for development. It belongs in `ERPLITE_API_BASE_URL`, not in git.
7. Whether local development uses HTTPS. App Transport Security blocks plain HTTP until a specific exception is added.
8. Authorization scope the server expects the client to understand, such as company, warehouse, or role. The server remains authoritative.

## What the client can already do

- Resolve a base URL and timeout from the bundled file and environment variables.
- Join `{baseURL}/{optional prefix}/{relative path}` and reject `..` segments.
- Encode and decode JSON with ISO-8601 dates, without renaming keys.
- Send with `URLSession`, map timeouts and HTTP status codes, and omit response bodies from errors.
- Attach credentials only through `RequestAuthorizing`.
- Store an opaque on-device secret in the keychain. Today that secret is a mock marker, not a backend token.
- Show mock screens that stay labeled as mock even if a base URL is present.

`AppConfiguration.contractIntegrated` stays `false` so UI code cannot describe this build as connected.

## What a later phase should change

1. Confirm the contract in `ERPLite` and record the real paths in this document.
2. Replace `PendingContractAuthorizer` with the published scheme. Do not leave the mock service pointed at that host.
3. Add `Codable` models under `Models/` that match the published JSON, then call `HTTPClientProtocol.send(_:as:)`.
4. Set `DataOrigin.backend` only on values decoded from a successful response. Keep the mock banner on anything still local.
5. Delete or gate `MockAuthService` once real sign-in is tested against the contract.

## Safety rules

- Do not commit production or development credentials.
- Do not commit a private network address.
- Do not log `Authorization` headers, cookies, or keychain contents.
- Do not treat a 200 from an unreviewed path as proof of an ERP Lite API.
- Keep using the in-process `URLProtocol` stub in tests. Do not point tests at a live ERP Lite environment.
