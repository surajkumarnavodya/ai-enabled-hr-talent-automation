import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { InterviewOutcome, InterviewStage, InterviewStatus } from "@/types/workflow";

// TODO(api-contract): replace with generated types once `npm run api:generate` has run.
export interface Interview {
  id: string;
  applicationId: string;
  candidateName: string;
  stage: InterviewStage;
  status: InterviewStatus;
  scheduledAt: string | null;
}

export function useInterviewList() {
  return useQuery({
    queryKey: [QUERY_KEYS.interviews, "list"],
    queryFn: () => http.get<Interview[]>("/v1/interviews"),
  });
}

export function useInterview(interviewId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.interviews, interviewId],
    queryFn: () => http.get<Interview>(`/v1/interviews/${interviewId}`),
    enabled: Boolean(interviewId),
  });
}

export interface SubmitFeedbackInput {
  outcome: InterviewOutcome;
  communicationScore: number;
  technicalScore: number;
  notes: string;
}

/**
 * Submitting feedback records the panelist's decision — it does not itself
 * advance or reject the candidate. The application moves to "Pending HR
 * Decision" until a human confirms progression via the TAN pipeline / offers
 * flow. See CLAUDE.md non-negotiable rules.
 */
export function useSubmitInterviewFeedback(interviewId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: SubmitFeedbackInput) =>
      http.post(`/v1/interviews/${interviewId}/feedback`, input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.interviews] });
    },
  });
}
