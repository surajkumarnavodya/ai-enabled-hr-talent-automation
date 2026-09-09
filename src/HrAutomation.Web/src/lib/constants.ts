import type { RoleName } from "@/types/auth";

/** Mirrors iam.Role.RoleName codes seeded in HrAutomationDb — see types/auth.ts header comment. */
export const ALL_ROLES: readonly RoleName[] = [
  "PLATFORM_ADMIN",
  "TENANT_ADMIN",
  "HR_ADMIN",
  "RECRUITER",
  "TALENT_ACQUISITION_MANAGER",
  "HIRING_MANAGER",
  "INTERVIEWER",
  "CLIENT_INTERVIEWER",
  "OFFER_APPROVER",
  "HR_OPERATIONS",
  "DOCUMENT_VERIFIER",
  "EMPLOYEE_ONBOARDING_ADMIN",
  "PAYROLL_INTEGRATION_USER",
  "IT_PROVISIONING_USER",
  "AUDITOR",
  "REPORTING_USER",
  "SUPPORT_READONLY",
  "CANDIDATE_PORTAL_USER",
  "AI_REVIEWER",
  "INTEGRATION_SERVICE",
];

export const HEADER_CORRELATION_ID = "X-Correlation-Id";
export const HEADER_IDEMPOTENCY_KEY = "Idempotency-Key";

export const QUERY_KEYS = {
  candidates: "candidates",
  cvBank: "cvBank",
  tans: "tans",
  matching: "matching",
  interviews: "interviews",
  offers: "offers",
  greenForms: "greenForms",
  verification: "verification",
  discrepancies: "discrepancies",
  approvals: "approvals",
  audit: "audit",
  admin: "admin",
} as const;

export const MAX_UPLOAD_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB — server enforces the authoritative limit.

export const ALLOWED_CV_MIME_TYPES = [
  "application/pdf",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
] as const;

export const ALLOWED_DOCUMENT_MIME_TYPES = [
  ...ALLOWED_CV_MIME_TYPES,
  "image/jpeg",
  "image/png",
] as const;
