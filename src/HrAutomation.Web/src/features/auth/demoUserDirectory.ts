import type { RoleName } from "@/types/auth";

/**
 * FAKE/DEMO identifiers only (@example.test), never real people. HrAutomationDb's
 * row-level security requires a real seeded tenant/user id — a randomly-generated
 * one fails the org.Tenant/iam.User foreign-key constraints (see DECISIONS_REQUIRED.md
 * DEC-007). This directory exists purely so `devTokenAuthProvider`'s role picker can
 * request a token for a real, already-seeded demo identity without a developer having
 * to look up GUIDs by hand. Source: src/HrAutomation.Infrastructure/Database/seed/
 * 01-seed-tenant-organization.sql and 03-seed-iam-users-access.sql. If reseeded with
 * different values, update this file to match.
 */
export const DEMO_TENANT_ID = "5B7EA628-5EE4-4680-865D-71CABB8463D7";

export const DEMO_USER_ID_BY_ROLE: Partial<Record<RoleName, string>> = {
  PLATFORM_ADMIN: "F10B311D-AF1E-4638-B30A-886DF1619439",
  TENANT_ADMIN: "7EC3629F-F533-4067-B4D0-A842549E4B5B",
  HR_ADMIN: "C3A025EE-42D8-4431-A10E-A7936C9555EF",
  RECRUITER: "708CEBD9-7BFA-4E87-9B10-FCE57092C46C",
  TALENT_ACQUISITION_MANAGER: "DEE92BF9-1380-434E-A1F7-5AEA5EB84CDB",
  HIRING_MANAGER: "609A215C-FFCA-4A4F-A24B-DD157A787AC2",
  INTERVIEWER: "BE9CE45E-B5B2-47DC-ADFF-405C4961C2A1",
  CLIENT_INTERVIEWER: "81FDB946-E0E7-46C1-B6E6-BBE8F2D280A9",
  OFFER_APPROVER: "E1F62201-6BEE-43C3-9AE2-037EAF05CC82",
  DOCUMENT_VERIFIER: "78754140-4DE0-48AC-B3E3-5A348467199B",
  EMPLOYEE_ONBOARDING_ADMIN: "3DD444E7-066E-400D-B11D-C59805E095DD",
  AUDITOR: "033805DB-0F63-4E36-989D-6A97B05FB783",
  REPORTING_USER: "706A7C8E-6860-4CAE-A6F8-24DDBA5CADB0",
  SUPPORT_READONLY: "FC932713-94B4-459B-A900-E4570E5ADC1D",
  AI_REVIEWER: "89B8CFA9-6DBE-4EAF-95DD-8D465AFFB36A",
  INTEGRATION_SERVICE: "510DB8C4-93CB-4F45-80F8-AFC4ED2B2F8C",
};

/** Roles with no dedicated seeded demo user yet — devToken login falls back to
 * letting the backend mint a fresh user_id for these (fine for roles with no
 * FK-dependent writes in the flows implemented so far). */
export const ROLES_WITHOUT_DEMO_USER: readonly RoleName[] = [
  "HR_OPERATIONS",
  "PAYROLL_INTEGRATION_USER",
  "IT_PROVISIONING_USER",
  "CANDIDATE_PORTAL_USER",
];
