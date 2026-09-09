/**
 * TEMPORARY hand-written types for HrAutomation.Api's generic response envelopes
 * (see types/workflow.ts header comment - same caveat applies: replace with
 * generated types once `npm run api:generate` runs against a corrected OpenAPI
 * contract). These mirror HrAutomation.Application.Contracts exactly:
 * - CursorPage<T>            <- Contracts/CommonDtos.cs
 * - AgentActionResponse      <- Contracts/AgentActionResponse.cs
 * Wire format is snake_case (Program.cs JsonNamingPolicy.SnakeCaseLower) -
 * these interfaces are written in snake_case on purpose so hooks can read the
 * JSON response directly without a silent-undefined mismatch.
 */

export interface CursorPage<T> {
  items: T[];
  next_cursor: string | null;
}

export type ActionStatus = "completed" | "pending_approval" | "blocked" | "failed" | "needs_human_review";
export type GuardrailResult = "pass" | "fail";

export interface GuardrailResultsDto {
  authorization: GuardrailResult;
  pii_check: GuardrailResult;
  prompt_injection_check: GuardrailResult;
  policy_check: GuardrailResult;
  schema_validation: GuardrailResult;
  all_pass: boolean;
}

export interface ExplanationDto {
  summary: string;
  job_related_evidence: string[];
  policy_sources: string[];
  confidence: number;
}

export interface AuditEventDto {
  event_type: string;
  timestamp_utc: string;
  actor_type: "User" | "System" | "AiAgent" | "ApiClient";
  actor_id: string;
}

/** The exact response envelope every action-style POST returns (spec section 12). */
export interface AgentActionResponse {
  request_id: string;
  trace_id: string;
  tenant_id: string;
  action: string;
  action_status: ActionStatus;
  workflow_id: string;
  tan_id: string | null;
  candidate_id: string | null;
  application_id: string | null;
  interview_round_id: string | null;
  offer_id: string | null;
  green_form_submission_id: string | null;
  employee_id: string | null;
  employee_number: string | null;
  current_state: string;
  proposed_next_state: string | null;
  data_updated: string[];
  explanation: ExplanationDto;
  required_approvals: string[];
  guardrail_results: GuardrailResultsDto;
  risks_or_exceptions: string[];
  next_allowed_actions: string[];
  audit_event: AuditEventDto;
}

export interface UserProfileDto {
  user_id: string;
  tenant_id: string;
  display_name: string;
  role: string;
  department_scope: string | null;
}

/** GET /v1/users/me/permissions - real, database-backed effective permissions
 * (iam.UserRole -> iam.Role -> iam.RolePermission -> iam.Permission), distinct
 * from the coarse UX-only Permission union in hooks/usePermissions.ts. */
export interface EffectivePermissionsDto {
  permissions: string[];
}

export interface AdminUserListItemDto {
  user_id: string;
  email: string;
  display_name: string;
  user_status: string;
  is_system_service_account: boolean;
  last_login_at_utc: string | null;
  created_at_utc: string;
  row_version: string;
}

export interface AdminUserRoleDto {
  user_role_id: string;
  role_id: string;
  role_name: string;
  assigned_at_utc: string;
}

export interface AdminUserDetailDto {
  user_id: string;
  tenant_id: string;
  email: string;
  display_name: string;
  user_status: string;
  is_system_service_account: boolean;
  first_name: string | null;
  last_name: string | null;
  phone_number: string | null;
  job_title: string | null;
  department_name: string | null;
  location_name: string | null;
  last_login_at_utc: string | null;
  created_at_utc: string;
  roles: AdminUserRoleDto[];
  row_version: string;
  allowed_actions: string[];
}
