import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage } from "@/types/api";

/** Mirrors HrAutomation.Application.Contracts.OfferDtos.OfferDto exactly.
 * NOTE: compensation is intentionally not exposed here — offer.OfferCompensation is a
 * RESTRICTED TABLE (see Database/scripts/03-create-tables.sql) with no write path yet; no
 * endpoint accepts or returns a compensation figure. See CLAUDE.md "Never store a compensation
 * figure as free text." */
export interface Offer {
  offer_id: string;
  candidate_application_id: string;
  offer_number: string;
  status: string;
  row_version: string;
}

export function useOfferList(cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.offers, "list", cursor ?? null],
    queryFn: () => http.get<CursorPage<Offer>>("/v1/offers", { params: { cursor, limit: 20 } }),
  });
}

export function useOffer(offerId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.offers, offerId],
    queryFn: () => http.get<Offer>(`/v1/offers/${offerId}`),
    enabled: Boolean(offerId),
  });
}

export function useCreateOffer(applicationId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () =>
      http.post("/v1/offers", { candidate_application_id: applicationId, offer_template_id: null }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] });
    },
  });
}

export function useApproveOffer(offerId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => http.post(`/v1/offers/${offerId}/approve`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] }),
  });
}

export function useSendOffer(offerId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => http.post(`/v1/offers/${offerId}/send`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.offers] }),
  });
}
