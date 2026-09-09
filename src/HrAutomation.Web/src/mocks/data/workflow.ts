import type { Interview } from "@/features/interviews/useInterviews";
import type { Offer } from "@/features/offers/useOffers";
import type { Discrepancy } from "@/features/discrepancies/useDiscrepancies";
import type { AuditLogEntry } from "@/types/workflow";
import type { DashboardSummary } from "@/features/dashboard/useDashboardSummary";
import type { VerificationQueueItem } from "@/features/verification/useVerification";
import type { ConversionCandidate } from "@/features/employee-conversion/useEmployeeConversion";
import type { PendingApproval } from "@/features/approvals/useApprovals";
import type { GreenFormDetails } from "@/features/green-form/useGreenForm";

/** All fixtures below are synthetic/demo data only. */

export const mockDashboardSummary: DashboardSummary = {
  active_tans: 6,
  candidates_awaiting_review: 3,
  interviews_scheduled_today: 2,
  pending_interview_feedback: 1,
  pending_approvals: 4,
  offers_pending_acceptance: 2,
  green_forms_pending: 1,
  high_severity_discrepancies: 1,
  employee_conversions_pending: 1,
  sla_breaches: 2,
};

export const mockInterviews: Interview[] = [
  {
    interview_round_id: "int-0001",
    candidate_application_id: "app-0001",
    candidate_name: "Asha Verma (demo)",
    stage: "L1",
    status: "Scheduled",
    scheduled_at: "2026-09-10T10:00:00Z",
  },
  {
    interview_round_id: "int-0002",
    candidate_application_id: "app-0002",
    candidate_name: "Ben Carter (demo)",
    stage: "L1",
    status: "Completed",
    scheduled_at: "2026-09-05T10:00:00Z",
  },
];

export const mockOffers: Offer[] = [
  {
    offer_id: "offer-0001",
    candidate_application_id: "app-0001",
    offer_number: "OFR-0001",
    status: "Draft",
    row_version: "AAAAAAAAB9E=",
  },
];

export const mockDiscrepancies: Discrepancy[] = [
  {
    id: "disc-0001",
    candidate_application_id: "app-0001",
    type: "DATE_MISMATCH",
    severity: "HIGH",
    status: "OPEN",
    description: "Self-reported employment end date does not match document evidence (demo data).",
  },
];

export const mockAuditLog: AuditLogEntry[] = [
  {
    id: "audit-0001",
    occurredAt: "2026-09-06T12:00:00Z",
    actorType: "human",
    actorLabel: "Demo HR Admin",
    action: "tan.approve",
    subjectType: "tan",
    subjectId: "tan-0001",
    outcome: "success",
  },
  {
    id: "audit-0002",
    occurredAt: "2026-09-06T13:00:00Z",
    actorType: "agent",
    actorLabel: "candidate_matching_skill",
    action: "matching.run",
    subjectType: "tan",
    subjectId: "tan-0001",
    outcome: "success",
  },
];

export const mockVerificationQueue: VerificationQueueItem[] = [
  {
    application_id: "app-0001",
    candidate_name: "Asha Verma (demo)",
    status: "InProgress",
    opened_at: "2026-09-04T08:00:00Z",
  },
];

export const mockConversionCandidates: ConversionCandidate[] = [
  {
    application_id: "app-0003",
    candidate_name: "Dana Kim (demo)",
    eligible: false,
    checklist: [
      { check: "Offer accepted", status: "pass" },
      { check: "Green Form complete", status: "pass" },
      { check: "Verification cleared", status: "pass" },
      { check: "No open discrepancies", status: "fail" },
    ],
  },
];

export const mockPendingApprovals: PendingApproval[] = [
  {
    id: "appr-0001",
    subject_type: "recruitment.JobRequisition",
    subject_label: "TAN-2026-000124 — Product Designer (demo)",
    action: "Approve TAN",
    requested_at: "2026-09-06T09:00:00Z",
  },
  {
    id: "appr-0002",
    subject_type: "offer.Offer",
    subject_label: "Offer for Asha Verma (demo)",
    action: "Approve offer",
    requested_at: "2026-09-06T11:00:00Z",
  },
];

export const mockGreenForm: GreenFormDetails = {
  id: "gf-0001",
  status: "InProgress",
  expires_at: "2026-09-14T00:00:00Z",
  required_documents: [
    { document_type: "Government ID", uploaded: false },
    { document_type: "Educational certificate", uploaded: false },
  ],
};
