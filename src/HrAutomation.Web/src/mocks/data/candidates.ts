import type { Candidate } from "@/types/workflow";

/** Synthetic/demo data only, shaped to match the real CandidateDto/CursorPage contract
 * exactly (see types/workflow.ts) — MSW/test-only, never real candidate information. */
export const mockCandidates: Candidate[] = [
  {
    candidate_id: "cand-0001",
    full_name: "Asha Verma (demo)",
    current_location: null,
    total_experience_months: 60,
    source: "CAREER_SITE",
    is_active: true,
    created_at_utc: "2026-08-01T09:00:00Z",
    row_version: "AAAAAAAAAAA=",
  },
  {
    candidate_id: "cand-0002",
    full_name: "Ben Carter (demo)",
    current_location: null,
    total_experience_months: 36,
    source: "JOB_PORTAL",
    is_active: true,
    created_at_utc: "2026-08-03T09:00:00Z",
    row_version: "AAAAAAAAAAB=",
  },
  {
    candidate_id: "cand-0003",
    full_name: "Chidi Okafor (demo)",
    current_location: null,
    total_experience_months: 84,
    source: "INTERNAL_REFERRAL",
    is_active: false,
    created_at_utc: "2026-07-20T09:00:00Z",
    row_version: "AAAAAAAAAAC=",
  },
];
