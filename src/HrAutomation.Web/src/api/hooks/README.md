# api/hooks/

**Status:** Empty — intentionally deferred.

Feature-specific TanStack Query hooks currently live colocated with their feature module (e.g. `src/features/tans/useTans.ts`), following the feature-first folder structure rule in `CLAUDE.md`.

This folder is reserved for **cross-cutting** query/mutation hooks that aren't owned by a single feature — for example, a shared `useLookupReferenceData` hook, or hooks generated directly from OpenAPI operation IDs if the team later adopts a codegen client (e.g. `openapi-react-query` or similar) on top of `src/api/generated/`.

Query keys are grouped by domain per `CLAUDE.md` state-management rules — see `src/lib/constants.ts` `QUERY_KEYS`.
