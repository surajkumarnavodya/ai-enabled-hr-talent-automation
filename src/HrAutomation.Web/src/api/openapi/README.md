# api/openapi/

**Status:** Reference-only — the canonical OpenAPI spec is NOT duplicated here.

The frontend-backend contract source of truth is `openapi/hr-onboarding-api.openapi.yaml` at the **repository root** (see `docs/04-api/`), not a copy inside this project. This folder exists so tooling has a conventional, documented place to look, and to hold any frontend-specific OpenAPI tooling config (e.g. an `openapi-typescript` config file) if one becomes necessary beyond the flags already passed in `scripts/generate-api-client.mjs`.

Run `npm run api:validate` (see `scripts/validate-openapi.mjs`) to check the root spec is present and well-formed before generating a client with `npm run api:generate`.

Do not hand-maintain a second copy of the spec here — that would defeat the "OpenAPI is the source of truth" rule in `CLAUDE.md`.
