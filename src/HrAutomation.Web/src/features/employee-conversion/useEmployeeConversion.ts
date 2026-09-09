import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage, AgentActionResponse } from "@/types/api";

/** Mirrors HrAutomation.Application.Contracts.EmployeeConversionDtos.ConversionChecklistItemDto. */
export interface ConversionChecklistItem {
  check: string;
  status: "pass" | "fail";
}

/** Mirrors HrAutomation.Application.Contracts.EmployeeConversionDtos.ConversionCandidateDto. */
export interface ConversionCandidate {
  application_id: string;
  candidate_name: string;
  eligible: boolean;
  checklist: ConversionChecklistItem[];
}

export function useConversionList() {
  return useQuery({
    queryKey: [QUERY_KEYS.approvals, "conversion-list"],
    queryFn: () => http.get<CursorPage<ConversionCandidate>>("/v1/employee-conversion"),
  });
}

export function useConversionDetail(applicationId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.approvals, "conversion", applicationId],
    queryFn: () => http.get<ConversionCandidate>(`/v1/employee-conversion/${applicationId}`),
    enabled: Boolean(applicationId),
  });
}

/**
 * Employee ID creation is a mandatory human-approval action gated on server
 * eligibility — the UI's "Create Employee ID" button is disabled until the
 * checklist and role are both satisfied, and even then only calls the API
 * after explicit confirmation. See CLAUDE.md.
 */
export function useConvertToEmployee(applicationId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () =>
      http.post<AgentActionResponse>(`/v1/applications/${applicationId}/convert-to-employee`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.approvals] }),
  });
}
