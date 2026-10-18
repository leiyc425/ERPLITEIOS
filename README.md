# ERP Lite iOS

Native SwiftUI client for the ERP Lite Django backend. Product branding is Flowmagik.

This repository is the iOS application only. ERP Lite remains the source of truth for business rules, records, authorization, and audit trails. The iOS app does not replace the Django project, and this phase does not call it.

The app signs in locally, shows mock clients, inventory units, and sales shaped like the Django models, and can call `GET /health/` when a base URL is configured. Business lists are not a live API.

- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)
- [API integration](docs/API_INTEGRATION.md)
- [Backend architecture](docs/BACKEND_ARCHITECTURE.md)
- [Data models](docs/DATA_MODELS.md)
- [API contract](docs/API_CONTRACT.md)
