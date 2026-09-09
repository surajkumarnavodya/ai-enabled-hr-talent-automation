import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage } from "@/types/api";

/** Mirrors HrAutomation.Api.Controllers.PendingApprovalDto exactly. */
export interface PendingApproval {
  id: string;
  subject_type: string;
  subject_label: string;
  action: string;
  requested_at: string;
}

export function usePendingApprovals() {
  return useQuery({
    queryKey: [QUERY_KEYS.approvals, "pending"],
    queryFn: () => http.get<CursorPage<PendingApproval>>("/v1/approvals"),
  });
}

export function useDecideApproval() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      decision,
    }: {
      id: string;
      decision: "approved" | "rejected" | "info_requested";
    }) => http.post(`/v1/approvals/${id}/decision`, { decision }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.approvals] }),
  });
}
