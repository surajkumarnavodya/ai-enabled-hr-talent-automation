import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { MatchResult } from "@/types/workflow";

export function useMatchResults(tanId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.matching, tanId],
    queryFn: () => http.get<MatchResult[]>(`/v1/tans/${tanId}/matches`),
    enabled: Boolean(tanId),
  });
}

/**
 * Shortlist approval is a mandatory human decision — this mutation only ever
 * fires after explicit confirmation in CandidateMatchesPage. The UI never
 * calls this automatically, and never rejects/advances a candidate itself;
 * see CLAUDE.md "The UI must never automatically reject or advance candidates."
 */
export function useApproveShortlist(tanId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (applicationId: string) =>
      http.post(`/v1/applications/${applicationId}/shortlist-approval`, { decision: "approved" }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.matching, tanId] });
    },
  });
}
