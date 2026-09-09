# api/generated/

**Status:** Empty — intentionally deferred.

This folder will hold TypeScript types (and, if adopted later, a generated client) produced by running:

```bash
npm run api:generate
```

which reads `../../openapi/hr-onboarding-api.openapi.yaml` (relative to this project root) via `openapi-typescript` and writes `schema.d.ts` here.

**Until this has been run and its output reviewed:**

- Feature modules use the temporary, hand-written types in `src/types/workflow.ts` and colocated feature-level types, each marked with a `TODO(api-contract)` comment.
- Do not hand-edit anything generated into this folder — regenerate from the spec instead.
- Do not commit generated output that hasn't been reviewed against a real backend contract change.

See `docs/04-api/frontend-api-integration.md` for the full contract-generation workflow and `src/api/openapi/README.md` for how the spec itself is validated.
