# ERP Lite iOS

Native SwiftUI client for the ERP Lite Django backend. Product branding is Flowmagik.

This repository is the iOS application only. ERP Lite remains the source of truth for business rules, records, authorization, and audit trails. The iOS app does not replace the Django project, and this phase does not call it.

Phase 0 is a local foundation: a mock sign-in shell, a dashboard of placeholders, and a `URLSession` client that stays idle until an HTTP contract exists.

- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)
- [API integration](docs/API_INTEGRATION.md)
