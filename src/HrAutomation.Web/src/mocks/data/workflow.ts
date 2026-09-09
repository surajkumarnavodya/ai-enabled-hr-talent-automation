import type { Interview } from "@/features/interviews/useInterviews";
import type { Offer } from "@/types/workflow";
import type { Discrepancy } from "@/types/workflow";
import type { AuditLogEntry } from "@/types/workflow";
import type { DashboardSummary } from "@/features/dashboard/useDashboardSummary";
import type { VerificationQueueItem } from "@/features/verification/useVerification";
import type { ConversionCandidate } from "@/features/employee-conversion/useEmployeeConversion";
import type { PendingApproval } from "@/features/approvals/useApprovals";
import type { GreenFormDetails } from "@/features/green-form/useGreenForm";

/** All fixtures below are synthetic/demo data only. */

export const mockDashboardSummary: DashboardSummary = {
  activeTans: 6,
  candidatesAwaitingReview: 3,
  interviewsScheduledToday: 2,
  pendingInterviewFeedback: 1,
  pendingApprovals: 4,
  offersPendingAcceptance: 2,
  greenFormsPending: 1,
  highSeverityDiscrepancies: 1,
  employeeConversionsPending: 1,
  slaBreaches: 2,
};

export const mockInterviews: Interview[] = [
  {
    id: "int-0001",
    applicationId: "app-0001",
    candidateName: "Asha Verma (demo)",
    stage: "L1",
    status: "scheduled",
    scheduledAt: "2026-09-10T10:00:00Z",
  },
  {
    id: "int-0002",
    applicationId: "app-0002",
    candidateName: "Ben Carter (demo)",
    stage: "L1",
    status: "completed",
    scheduledAt: "2026-09-05T10:00:00Z",
  },
];

export const mockOffers: Offer[] = [
  {
    id: "offer-0001",
    applicationId: "app-0001",
    status: "drafted",
    compensationRef: "comp-ref-G4-demo",
    templateVersion: "offer-template-v2",
  },
];

export const mockDiscrepancies: Discrepancy[] = [
  {
    id: "disc-0001",
    applicationId: "app-0001",
    type: "employment_dates_mismatch",
    severity: "high",
    status: "raised",
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
    applicationId: "app-0001",
    candidateName: "Asha Verma (demo)",
    outcome: "needs_review",
    submittedAt: "2026-09-04T08:00:00Z",
  },
];

export const mockConversionCandidates: ConversionCandidate[] = [
  {
    applicationId: "app-0003",
    candidateName: "Dana Kim (demo)",
    eligible: false,
    checklist: [
      { check: "Offer accepted", status: "pass" },
      { check: "Green Form complete", status: "pass" },
      { check: "Documents verified", status: "pending" },
      { check: "No open discrepancies", status: "fail" },
    ],
  },
];

export const mockPendingApprovals: PendingApproval[] = [
  {
    id: "appr-0001",
    subjectType: "tan",
    subjectLabel: "TAN-2026-000124 — Product Designer (demo)",
    action: "Approve TAN",
    requestedAt: "2026-09-06T09:00:00Z",
  },
  {
    id: "appr-0002",
    subjectType: "offer",
    subjectLabel: "Offer for Asha Verma (demo)",
    action: "Approve offer",
    requestedAt: "2026-09-06T11:00:00Z",
  },
];

export const mockGreenForm: GreenFormDetails = {
  id: "gf-0001",
  status: "issued",
  expiresAt: "2026-09-14T00:00:00Z",
  requiredDocuments: [
    { documentType: "Government ID", uploaded: false },
    { documentType: "Educational certificate", uploaded: false },
  ],
};
