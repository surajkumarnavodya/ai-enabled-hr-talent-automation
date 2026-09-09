import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { VerificationOutcome } from "@/types/workflow";

// TODO(api-contract): replace with generated types once `npm run api:generate` has run.
export interface VerificationQueueItem {
  applicationId: string;
  candidateName: string;
  outcome: VerificationOutcome;
  submittedAt: string;
}

export function useVerificationQueue() {
  return useQuery({
    queryKey: [QUERY_KEYS.verification, "queue"],
    queryFn: () => http.get<VerificationQueueItem[]>("/v1/verification"),
  });
}

export function useVerificationDetail(applicationId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.verification, applicationId],
    queryFn: () => http.get<VerificationQueueItem>(`/v1/verification/${applicationId}`),
    enabled: Boolean(applicationId),
  });
}
