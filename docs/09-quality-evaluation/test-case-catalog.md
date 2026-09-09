# Test Case Catalog

> Title: Test Case Catalog | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — QA Lead] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: QA, Security

## Purpose and scope

Representative test cases per tier from [test-strategy.md](test-strategy.md). This is a starter catalog, not exhaustive — extend as implementation proceeds.

## Representative test cases

| ID | Tier | Scenario | Expected result |
|---|---|---|---|
| TC-001 | Unit | Attempt illegal workflow transition (e.g., `Recommended` → `OfferSent`) | Rejected with `409`, no state change, no audit entry for a false "success" |
| TC-002 | Integration | Create TAN, approve, trigger matching | Match scores persisted, referencing correct `tan_id`/`jd_version` |
| TC-003 | Contract | POST `/tans` with missing `mandatoryCriteria` | `422` per OpenAPI schema, RFC 7807 body |
| TC-004 | End-to-end | Full happy path: CV upload → TAN → match → shortlist approval → L1 select → L2 select → offer approval → acceptance → Green Form → verification clean → employee conversion | Employee record created, all approval records present, all events emitted |
| TC-005 | End-to-end | L1 rejection path | Application closed for TAN, alternate recommendations generated, candidate remains in CV Bank |
| TC-006 | Security | Attempt cross-tenant read of another tenant's TAN using a valid but different-tenant token | `404` (indistinguishable from true not-found) |
| TC-007 | Security | Attempt to call `/offers/{id}/send` without a prior `approve` | `409`, audit log records denied attempt |
| TC-008 | Performance | 1,000 concurrent CV uploads | p95 upload-acceptance latency within NFR target, no dropped uploads |
| TC-009 | Accessibility | Green Form candidate flow via screen reader | All fields labeled, keyboard-navigable, WCAG target met |
| TC-010 | Chaos/resilience | Kill outbox relay mid-processing, restart | No event loss; all pending outbox rows eventually delivered |
| TC-011 | RAG evaluation | Ask a policy question with no matching indexed content | No-answer fallback returned, no hallucinated answer |
| TC-012 | Agent/skill evaluation | Run matching skill against fairness test set (profiles differing only in excluded characteristics) | Score distributions show no statistically significant disparity |
| TC-013 | MCP integration | Attempt approval-required write tool call without a recorded approval | Tool Gateway blocks call, logs denial |
| TC-014 | MCP integration | Simulate calendar MCP server timeout | Circuit breaker opens after threshold, recruiter notified of fallback |
| TC-015 | Human acceptance | HR Approver walks through TAN-to-offer flow in staging | Sign-off recorded against [acceptance-criteria.md](acceptance-criteria.md) |

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
