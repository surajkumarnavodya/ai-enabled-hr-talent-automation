import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { Discrepancy } from "@/types/workflow";

export function useDiscrepancyList() {
  return useQuery({
    queryKey: [QUERY_KEYS.discrepancies, "list"],
    queryFn: () => http.get<Discrepancy[]>("/v1/discrepancies"),
  });
}

export function useDiscrepancy(discrepancyId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.discrepancies, discrepancyId],
    queryFn: () => http.get<Discrepancy>(`/v1/discrepancies/${discrepancyId}`),
    enabled: Boolean(discrepancyId),
  });
}

export function useRequestReupload(discrepancyId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (reason: string) =>
      http.post(`/v1/discrepancies/${discrepancyId}/reupload-request`, { reason }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.discrepancies] }),
  });
}

/**
 * Resolving/granting an exception for a discrepancy is a mandatory
 * HR-approval action — never triggered automatically or optimistically.
 * See CLAUDE.md state-management rules.
 */
export function useResolveDiscrepancy(discrepancyId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (decision: "approved" | "rejected") =>
      http.post(`/v1/discrepancies/${discrepancyId}/resolve`, { decision }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.discrepancies] }),
  });
}
