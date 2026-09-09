import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";

// TODO(api-contract): replace with generated types once `npm run api:generate` has run.
export interface PendingApproval {
  id: string;
  subjectType: string;
  subjectLabel: string;
  action: string;
  requestedAt: string;
}

export function usePendingApprovals() {
  return useQuery({
    queryKey: [QUERY_KEYS.approvals, "pending"],
    queryFn: () => http.get<PendingApproval[]>("/v1/approvals"),
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
