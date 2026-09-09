/**
 * TEMPORARY hand-written domain types.
 *
 * TODO(api-contract): The canonical contract is openapi/hr-onboarding-api.openapi.yaml
 * at the repository root. Once `npm run api:generate` has been run against it (see
 * scripts/generate-api-client.mjs and src/api/generated/README.md), replace every
 * type in this file with the corresponding generated type and delete this file.
 * Do not let hand-written and generated types drift — this file exists only so the
 * UI scaffold compiles and renders against MSW mocks before generation is wired
 * into CI. See docs/04-api/frontend-api-integration.md.
 */

export type TanStatus = "draft" | "pending_approval" | "approved" | "on_hold" | "closed";

export type ApplicationStatus =
  | "recommended"
  | "shortlist_approved"
  | "l1_scheduled"
  | "l1_feedback_captured"
  | "l2_scheduled"
  | "l2_feedback_captured"
  | "client_scheduled"
  | "client_feedback_captured"
  | "final_selection_pending"
  | "final_selection_approved"
  | "offer_sent"
  | "offer_accepted"
  | "offer_declined"
  | "onboarding_in_progress"
  | "converted"
  | "closed_for_tan";

export type GreenFormStatus = "issued" | "submitted" | "expired" | "revoked";

/**
 * Mirrors HrAutomation.Application.Contracts.TanDtos.TanDto exactly (snake_case
 * wire format). NOTE: Location/Grade are always empty strings today - the real
 * recruitment.JobRequisition table has no backing column for them yet (see
 * DECISIONS_REQUIRED.md DEC-004) - do not build UI that assumes they're populated.
 */
export interface Tan {
  tan_id: string;
  tan_number: string;
  title: string;
  location: string;
  grade: string;
  status: string;
  row_version: string;
}

/** Mirrors HrAutomation.Application.Contracts.CandidateDtos.CandidateDto exactly. */
export interface Candidate {
  candidate_id: string;
  full_name: string;
  current_location: string | null;
  total_experience_months: number;
  source: string;
  is_active: boolean;
  created_at_utc: string;
  row_version: string;
}

export interface MatchResult {
  applicationId: string;
  candidateId: string;
  candidateName: string;
  score: number;
  matchedMandatory: string[];
  missingMandatory: string[];
  matchedPreferred: string[];
  evidenceSummary: string;
  risks: string[];
  modelVersion: string;
}

export interface Application {
  id: string;
  tanId: string;
  candidateId: string;
  status: ApplicationStatus;
}

export interface AuditLogEntry {
  id: string;
  occurredAt: string;
  actorType: "human" | "agent" | "system";
  actorLabel: string;
  action: string;
  subjectType: string;
  subjectId: string;
  outcome: "success" | "denied" | "error";
}
