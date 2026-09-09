import { useMutation, useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";

/** Mirrors HrAutomation.Application.Contracts.GreenFormDtos.GreenFormDetailsDto exactly. */
export interface GreenFormDetails {
  id: string;
  status: string;
  expires_at: string;
  required_documents: { document_type: string; uploaded: boolean }[];
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

/** Mirrors HrAutomation.Application.Contracts.GreenFormDtos.SubmitGreenFormRequest exactly. */
export interface GreenFormSubmitInput {
  employmentHistory: { employerName: string; startDate: string; endDate?: string }[];
  education: { institution: string; qualification: string; year: number }[];
}

export function useSubmitGreenForm(token: string) {
  return useMutation({
    mutationFn: (input: GreenFormSubmitInput) =>
      http.post(`/v1/green-forms/by-token/${token}/submissions`, {
        employment_history: input.employmentHistory.map((e) => ({
          employer_name: e.employerName,
          start_date: e.startDate,
          end_date: e.endDate ?? null,
        })),
        education: input.education.map((e) => ({
          institution: e.institution,
          qualification: e.qualification,
          year: e.year,
        })),
      }),
  });
}
