import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage } from "@/types/api";

/** Mirrors HrAutomation.Application.Contracts.VerificationDtos.VerificationQueueItemDto exactly. */
export interface VerificationQueueItem {
  application_id: string;
  candidate_name: string;
  status: string;
  opened_at: string;
}

export function useVerificationQueue(cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.verification, "queue", cursor ?? null],
    queryFn: () =>
      http.get<CursorPage<VerificationQueueItem>>("/v1/verification", {
        params: { cursor, limit: 20 },
      }),
  });
}

export function useVerificationDetail(applicationId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.verification, applicationId],
    queryFn: () => http.get<VerificationQueueItem>(`/v1/verification/${applicationId}`),
    enabled: Boolean(applicationId),
  });
}
