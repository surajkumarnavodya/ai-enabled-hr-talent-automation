import type { Tan } from "@/types/workflow";
import type { MatchResult } from "@/types/workflow";

/** Synthetic/demo data only, shaped to match the real TanDto/CursorPage contract exactly
 * (see types/workflow.ts, types/api.ts) — MSW/test-only, never used at real runtime. */
export const mockTans: Tan[] = [
  {
    tan_id: "tan-0001",
    tan_number: "TAN-2026-000123",
    title: "Senior Backend Engineer (demo)",
    location: "",
    grade: "",
    status: "Approved",
    row_version: "AAAAAAAAAAA=",
  },
  {
    tan_id: "tan-0002",
    tan_number: "TAN-2026-000124",
    title: "Product Designer (demo)",
    location: "",
    grade: "",
    status: "PendingApproval",
    row_version: "AAAAAAAAAAB=",
  },
];

export const mockMatchResults: Record<string, MatchResult[]> = {
  "tan-0001": [
    {
      applicationId: "app-0001",
      candidateId: "cand-0001",
      candidateName: "Asha Verma (demo)",
      score: 87,
      matchedMandatory: ["5+ years backend experience", "Distributed systems"],
      missingMandatory: [],
      matchedPreferred: ["Kubernetes"],
      evidenceSummary:
        "6 years at a fintech scale-up building distributed payment systems (demo evidence).",
      risks: ["Employment gap of 3 months in 2024 — reason not specified in CV"],
      modelVersion: "matching-v1.3-demo",
    },
    {
      applicationId: "app-0002",
      candidateId: "cand-0002",
      candidateName: "Ben Carter (demo)",
      score: 62,
      matchedMandatory: ["5+ years backend experience"],
      missingMandatory: ["Distributed systems"],
      matchedPreferred: [],
      evidenceSummary:
        "Primarily frontend-leaning experience with limited backend depth (demo evidence).",
      risks: ["Possible duplicate CV on file — recruiter review recommended"],
      modelVersion: "matching-v1.3-demo",
    },
  ],
};
