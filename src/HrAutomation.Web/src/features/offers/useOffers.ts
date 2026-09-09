import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { Offer } from "@/types/workflow";

export function useOfferList() {
  return useQuery({
    queryKey: [QUERY_KEYS.offers, "list"],
    queryFn: () => http.get<Offer[]>("/v1/offers"),
  });
}

export function useOffer(offerId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.offers, offerId],
    queryFn: () => http.get<Offer>(`/v1/offers/${offerId}`),
    enabled: Boolean(offerId),
  });
}

/**
 * Compensation is never computed or entered as a free-value here — only a
 * reference into the external compensation system is sent, and the rendered
 * figure (if any) always comes verbatim from the API response. See
 * CLAUDE.md "No salary computations in client-side logic".
 */
export function useCreateOffer(applicationId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { compensationRef: string; templateVersion: string }) =>
      http.post<Offer>(`/v1/applications/${applicationId}/offers`, input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] });
    },
  });
}

export function useApproveOffer(offerId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => http.post<Offer>(`/v1/offers/${offerId}/approve`, { decision: "approved" }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] }),
  });
}

export function useSendOffer(offerId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => http.post<Offer>(`/v1/offers/${offerId}/send`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] }),
  });
}
