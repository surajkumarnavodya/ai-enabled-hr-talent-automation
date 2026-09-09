import { useMutation, useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { GreenFormStatus } from "@/types/workflow";

// TODO(api-contract): replace with generated types once `npm run api:generate` has run.
export interface GreenFormDetails {
  id: string;
  status: GreenFormStatus;
  expiresAt: string;
  requiredDocuments: { documentType: string; uploaded: boolean }[];
}

/** Candidate-facing — authorized by the possession of a single-use token, not an internal session. */
export function useGreenFormByToken(token: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.greenForms, "token", token],
    queryFn: () => http.get<GreenFormDetails>(`/v1/green-forms/by-token/${token}`),
    enabled: Boolean(token),
  });
}

export function useGreenFormSubmission(submissionId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.greenForms, "submission", submissionId],
    queryFn: () => http.get<GreenFormDetails>(`/v1/green-forms/submission/${submissionId}`),
    enabled: Boolean(submissionId),
  });
}

export interface GreenFormSubmitInput {
  employmentHistory: { employerName: string; startDate: string; endDate?: string }[];
  education: { institution: string; qualification: string; year: number }[];
}

export function useSubmitGreenForm(token: string) {
  return useMutation({
    mutationFn: (input: GreenFormSubmitInput) =>
      http.post(`/v1/green-forms/by-token/${token}/submissions`, input),
  });
}
