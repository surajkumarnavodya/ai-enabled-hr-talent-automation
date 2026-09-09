import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage } from "@/types/api";

/** Mirrors HrAutomation.Application.Contracts.DiscrepancyDtos.DiscrepancyDto exactly.
 * type/severity/status are the real ref.DiscrepancyType/Severity/Status codes
 * (UPPER_SNAKE_CASE) verbatim — not the lowercase unions this hook used to declare. */
export interface Discrepancy {
  id: string;
  candidate_application_id: string;
  type: string;
  severity: string;
  status: string;
  description: string;
}

export function useDiscrepancyList(cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.discrepancies, "list", cursor ?? null],
    queryFn: () =>
      http.get<CursorPage<Discrepancy>>("/v1/discrepancies", { params: { cursor, limit: 20 } }),
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
