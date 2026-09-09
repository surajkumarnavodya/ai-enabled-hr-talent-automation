# Master Data Management

> Title: Master Data Management | Version: 1.0 | Owner: [TENANT_CONFIGURATION_REQUIRED — Data Architecture] | Status: Draft | Last reviewed: 2026-09-07 | Next review: [TENANT_CONFIGURATION_REQUIRED] | Reviewers: Architecture, HR Operations

## Purpose and scope

Defines the master (reference) data domains, their source of truth, and synchronization rules with external systems (notably HRMS, which often owns organizational reference data).

## Master data domains

| Domain | Source of truth | Synchronized to | Sync pattern |
|---|---|---|---|
| Departments / business units / locations | HRMS (external) or platform admin config, per tenant choice | Platform reference tables | Scheduled pull or event-driven push via `mcp-hrms` |
| Job grades / roles | HRMS or tenant config | Platform reference tables, used in TAN/offer templates | Scheduled pull |
| Compensation bands | HRMS/Compensation system (external) | Referenced by ID only from Offer entity — never copied as free text | Real-time lookup or cached with short TTL |
| Employee master (post-conversion) | Platform (system of record for the hire event) → HRMS (system of record post-onboarding) | HRMS, Payroll, IT Provisioning | Event-driven push on `employee.created` |
| Approval role/user directory | Identity provider / HRMS org chart | Platform RBAC/ABAC assignments | Scheduled pull + on-demand refresh |

## Ownership boundary

The platform is the system of record for the **recruitment-to-conversion** event; once an employee is created and handed off via `employee.created`, HRMS becomes authoritative for ongoing employee lifecycle data. The platform retains its own historical record (immutable) for audit purposes but does not attempt to stay in sync with post-hire HRMS changes (e.g., later promotions) — that is out of scope for this platform.

## Conflict handling

If HRMS reference data changes after a TAN/offer was created referencing the old value (e.g., a department is renamed), the platform keeps a point-in-time snapshot on the TAN/offer record rather than a live foreign-key that could silently change historical documents. New TANs/offers use the current reference data.

## Configurable items

Which system is authoritative for departments/grades per tenant, sync frequency, and caching TTLs are tenant-configurable.

## Risks and open questions

- Tenants without a modern HRMS API (batch-file-only) need a fallback sync adapter — see [integration-architecture.md](../01-architecture/integration-architecture.md) risk note.

## Change control

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-07 | Documentation package generation | Initial creation |
