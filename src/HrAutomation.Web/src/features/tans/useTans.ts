import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { Tan } from "@/types/workflow";
import type { AgentActionResponse, CursorPage } from "@/types/api";

export function useTanList(cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.tans, "list", cursor ?? null],
    queryFn: () => http.get<CursorPage<Tan>>("/v1/tans", { params: { cursor, limit: 20 } }),
  });
}

export function useTan(tanId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.tans, tanId],
    queryFn: () => http.get<Tan>(`/v1/tans/${tanId}`),
    enabled: Boolean(tanId),
  });
}

/** Mirrors HrAutomation.Application.Contracts.TanDtos.CreateTanRequest exactly.
 * NOTE: location/grade/budget/interview-stage/criteria fields are accepted by the API but
 * currently NOT persisted (recruitment.JobRequisition has no backing column for them yet -
 * see DECISIONS_REQUIRED.md DEC-004). Sent anyway so the request is forward-compatible once
 * that gap is resolved; do not assume they round-trip back from a GET today. */
export interface CreateTanInput {
  title: string;
  location: string;
  grade: string;
  budget_min: number;
  budget_max: number;
  interview_stages_count: number;
  client_interview_required: boolean;
  mandatory_criteria_json: string;
  preferred_criteria_json: string;
  raw_description: string;
}

export function useCreateTan() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateTanInput) => http.post<AgentActionResponse>("/v1/tans", input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.tans] });
    },
  });
}

export type TanApprovalDecision = "Approved" | "Rejected" | "ReturnedForInfo";

/** Approving/rejecting a TAN is a mandatory-human-approval action — always confirmed in the
 * UI first, never optimistic. source_version is required by the API contract but is not
 * currently enforced server-side for optimistic concurrency (see TanApprovalSkill's class
 * comment) - sent as a fixed value until that's resolved. */
export function useApproveTan(tanId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { decision: TanApprovalDecision; comments?: string }) =>
      http.post<AgentActionResponse>(`/v1/tans/${tanId}/approve`, {
        decision: input.decision,
        comments: input.comments,
        source_version: 1,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.tans] });
    },
  });
}
