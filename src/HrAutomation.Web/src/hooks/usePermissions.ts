import { useMemo } from "react";
import type { RoleName } from "@/types/auth";
import { useAuth } from "@/hooks/useAuth";

/**
 * UI-side capability model — purely for showing/hiding affordances and route
 * guarding UX. This is NOT the authorization boundary: HrAutomation.Api
 * re-checks every sensitive action server-side regardless of what the UI
 * shows. See docs/05-security-governance/frontend-security.md.
 *
 * Role descriptions mirror src/HrAutomation.Infrastructure/Database/seed/
 * 02-seed-iam-roles-permissions.sql - this mapping is a best-effort UI
 * approximation of that seed data's role descriptions, not itself the source
 * of truth (there is no dedicated "what can this role click" API yet).
 */
export type Permission =
  | "tan.approve"
  | "shortlist.approve"
  | "offer.approve"
  | "offer.send"
  | "discrepancy.resolve"
  | "employee.convert"
  | "interview.feedback.submit"
  | "document.verify"
  | "audit.read"
  | "admin.access";

const ROLE_PERMISSIONS: Record<RoleName, Permission[]> = {
  PLATFORM_ADMIN: [],
  TENANT_ADMIN: ["audit.read", "admin.access"],
  HR_ADMIN: [
    "tan.approve",
    "shortlist.approve",
    "offer.approve",
    "offer.send",
    "discrepancy.resolve",
    "employee.convert",
    "audit.read",
    "admin.access",
  ],
  RECRUITER: [],
  TALENT_ACQUISITION_MANAGER: ["tan.approve", "shortlist.approve"],
  HIRING_MANAGER: ["shortlist.approve", "interview.feedback.submit"],
  INTERVIEWER: ["interview.feedback.submit"],
  CLIENT_INTERVIEWER: ["interview.feedback.submit"],
  OFFER_APPROVER: ["offer.approve", "offer.send"],
  HR_OPERATIONS: ["document.verify"],
  DOCUMENT_VERIFIER: ["document.verify", "discrepancy.resolve"],
  EMPLOYEE_ONBOARDING_ADMIN: ["employee.convert"],
  PAYROLL_INTEGRATION_USER: [],
  IT_PROVISIONING_USER: [],
  AUDITOR: ["audit.read"],
  REPORTING_USER: ["audit.read"],
  SUPPORT_READONLY: [],
  CANDIDATE_PORTAL_USER: [],
  AI_REVIEWER: [],
  INTEGRATION_SERVICE: [],
};

export interface UsePermissionsResult {
  role: RoleName | null;
  hasPermission: (permission: Permission) => boolean;
  hasAnyRole: (roles: RoleName[]) => boolean;
}

export function usePermissions(): UsePermissionsResult {
  const { user } = useAuth();

  return useMemo(() => {
    const role = user?.role ?? null;
    const grants = role ? ROLE_PERMISSIONS[role] : [];
    return {
      role,
      hasPermission: (permission: Permission) => grants.includes(permission),
      hasAnyRole: (roles: RoleName[]) => (role ? roles.includes(role) : false),
    };
  }, [user]);
}
