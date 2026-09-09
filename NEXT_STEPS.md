# Next Steps

> Status: Reconciled against real implementation state (2026-09-08). Checked items have direct evidence (real code/build/test run) behind them; unchecked items are genuinely not done or not confirmed — see [PROJECT_STATUS.md](PROJECT_STATUS.md) for detail and evidence per item.

Prioritized checklist to move from this foundation to a working platform. Owners: **HR**, **Product**, **Engineering**, **Security**, **Legal/Privacy**, **DevOps**, **QA**, **Data/AI**.

## Phase 0: Organization decisions

- [ ] Confirm business owner. — Owner: Product
- [ ] Confirm HR workflow owner. — Owner: HR
- [ ] Confirm legal/privacy owner. — Owner: Legal/Privacy
- [ ] Confirm security owner. — Owner: Security
- [ ] Confirm tenant model (single-tenant per deployment vs. shared multi-tenant). — Owner: Engineering
- [ ] Confirm target cloud provider and region(s). — Owner: DevOps
- [ ] Confirm identity provider (Entra ID, Okta, Auth0, etc.). — Owner: Security
- [ ] Confirm data-retention policy per data category. — Owner: Legal/Privacy
- [ ] Confirm approval matrix (who approves TAN, shortlist, offer, discrepancy closure, employee conversion). — Owner: HR
- [ ] Confirm integration providers (HRMS, payroll, calendar/email, e-signature, IT provisioning). — Owner: Product + DevOps
- [ ] Confirm legal offer templates and Green Form content. — Owner: Legal/Privacy + HR

## Phase 1: Architecture and contracts

- [ ] Produce/finalize PRD, workflow state machine, ERD, data dictionary. — Owner: Product + Engineering
- [ ] Finalize OpenAPI and AsyncAPI contracts against Phase 0 decisions. — Owner: Engineering
- [ ] Record architecture decisions as ADRs. — Owner: Engineering
- [ ] Define/finalize configuration schemas (`config/schemas/`). — Owner: Engineering
- [ ] Define RBAC/ABAC matrix. — Owner: Security
- [ ] Define audit event taxonomy. — Owner: Security + Engineering

## Phase 2: Foundation

- [x] Bootstrap/confirm .NET backend structure (existing `src/HrAutomation.*` solution). — Owner: Engineering — done; solution builds and its test suite passes.
- [x] Bootstrap React frontend. — Owner: Frontend Engineering — done as `src/HrAutomation.Web` (Vite + React, not Next.js); runs today in mock-API mode only, not yet wired to the real backend.
- [ ] Bootstrap Python agent service under `src/agents/`. — Owner: Data/AI — **not done, and not the direction taken**: AI skills are implemented as C# `ISkill` classes inside `HrAutomation.Agents`, in-process with the API. Revisit only if a real need for a separate agent runtime emerges — see `DECISIONS_REQUIRED.md`.
- [ ] Bootstrap infrastructure as code under `infra/`. — Owner: DevOps — not started.
- [ ] Stand up CI/CD pipelines (`.github/workflows/`). — Owner: DevOps — workflow files exist (`ci.yml`, `docs-validation.yml`, `security-scan.yml`) but have not been verified to run green against the real solution.
- [x] Implement authentication and tenant isolation (dev-only). — Owner: Engineering + Security — dev-only symmetric-key JWT (`/api/v1/dev/token`, gated to Development environment) + SQL Server row-level security via `SESSION_CONTEXT('TenantId')`. **Not production-ready**: no real OIDC/OAuth 2.1 provider is wired up yet (frontend `oidcAuthProvider.ts` is an intentional stub that throws).
- [ ] Implement secrets management (vault integration). — Owner: DevOps + Security — local dev uses `dotnet user-secrets`; no vault integration exists.
- [ ] Implement logging redaction. — Owner: Engineering + Security — not verified this pass; `src/lib/safeLogger.ts` exists on the frontend, backend redaction not confirmed.
- [ ] Implement health checks and config validation on startup. — Owner: Engineering — not verified.

## Phase 3: Incremental workflow delivery

- [x] Candidate CV Bank (upload, parse, dedupe-suggestion). — Owner: Engineering — done; verified end-to-end against the real API/database. Dedup is suggestion-only (`recruitment.usp_CreateDuplicateReview`), never an auto-merge, per the human-in-the-loop rule.
- [x] TAN and JD creation/approval. — Owner: Engineering + HR — done for create/submit/approve/reject; verified end-to-end. JD content is limited to title + free-text description today (see `DECISIONS_REQUIRED.md` for the JD structured-fields gap).
- [ ] Matching recommendations and shortlist approval. — Owner: Data/AI + Engineering — stub only, always returns "blocked, not yet implemented."
- [ ] Interview scheduling and feedback (L1/L2/client). — Owner: Engineering
- [ ] Offer generation, approval, acceptance, e-signature. — Owner: Engineering + HR + Legal
- [ ] Green Form and document collection. — Owner: Engineering
- [ ] Verification and discrepancy management. — Owner: Engineering + HR
- [ ] Employee conversion and downstream integrations. — Owner: Engineering + HR + DevOps

## Phase 4: AI safety and quality

- [ ] Build the RAG corpus and ingestion pipeline. — Owner: Data/AI
- [ ] Build evaluation datasets and automated evaluation runs. — Owner: Data/AI + QA
- [ ] Run prompt-injection red-team tests. — Owner: Security + Data/AI
- [ ] Establish human-review sampling and fairness controls. — Owner: Data/AI + HR + Legal
- [ ] Stand up monitoring, alerting, cost controls, and a rollback drill. — Owner: DevOps + Engineering

## Related documents

[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) · [CLAUDE.md](CLAUDE.md) · [docs/10-delivery/](docs/10-delivery/) · [docs/00-product/scope-assumptions-open-questions.md](docs/00-product/scope-assumptions-open-questions.md)
