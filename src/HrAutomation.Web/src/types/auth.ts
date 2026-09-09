/**
 * Role names mirror `iam.Role.RoleName` codes seeded in HrAutomationDb exactly
 * (see src/HrAutomation.Infrastructure/Database/seed/02-seed-iam-roles-permissions.sql) —
 * NOT a fixed C# enum; the backend's `RequestContext.Role` is a plain string read
 * from the JWT `role` claim. This is the single fixed source of truth for role
 * identifiers on the frontend, but the API is always the final authority on what
 * a user may do; these values only drive UI affordances (showing/hiding actions,
 * route guarding for UX). See docs/05-security-governance/frontend-security.md
 * "Authorization is not enforced here".
 */
export type RoleName =
  | "PLATFORM_ADMIN"
  | "TENANT_ADMIN"
  | "HR_ADMIN"
  | "RECRUITER"
  | "TALENT_ACQUISITION_MANAGER"
  | "HIRING_MANAGER"
  | "INTERVIEWER"
  | "CLIENT_INTERVIEWER"
  | "OFFER_APPROVER"
  | "HR_OPERATIONS"
  | "DOCUMENT_VERIFIER"
  | "EMPLOYEE_ONBOARDING_ADMIN"
  | "PAYROLL_INTEGRATION_USER"
  | "IT_PROVISIONING_USER"
  | "AUDITOR"
  | "REPORTING_USER"
  | "SUPPORT_READONLY"
  | "CANDIDATE_PORTAL_USER"
  | "AI_REVIEWER"
  | "INTEGRATION_SERVICE";

export interface AuthenticatedUser {
  userId: string;
  tenantId: string;
  displayName: string;
  role: RoleName;
  departmentScope?: string;
}

export type AuthStatus = "idle" | "authenticating" | "authenticated" | "unauthenticated" | "error";

export interface AuthState {
  status: AuthStatus;
  user: AuthenticatedUser | null;
  error: string | null;
}

/**
 * Auth provider abstraction. Exactly one implementation is active at a time,
 * selected by `VITE_AUTH_MODE` (see app/config/env.ts) — never hardcoded.
 * Implementations: `mockAuthProvider` (local dev, no network) and
 * `oidcAuthProvider` (real OAuth 2.1 / OIDC, or a BFF cookie-session adapter).
 * No implementation may persist a raw access/refresh token to localStorage or
 * sessionStorage — see docs/05-security-governance/frontend-security.md.
 */
export interface AuthProvider {
  /** Restore session on app boot (e.g. validate a BFF cookie session or silent-refresh). */
  initialize(): Promise<AuthenticatedUser | null>;
  login(input?: MockLoginInput): Promise<AuthenticatedUser>;
  logout(): Promise<void>;
  /** Returns a bearer token for the API client to attach, or null if using cookie auth. */
  getAccessToken(): Promise<string | null>;
}

/** Only meaningful for the mock provider; real providers ignore this. */
export interface MockLoginInput {
  role: RoleName;
  displayName?: string;
}
