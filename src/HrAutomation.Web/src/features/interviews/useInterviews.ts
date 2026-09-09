import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { CursorPage } from "@/types/api";

/** Mirrors HrAutomation.Application.Contracts.InterviewDtos.InterviewDto exactly.
 * One row = one recruitment.InterviewRound (a single stage — L1, L2, Client, ...); "id" below
 * is InterviewRoundId, the granularity feedback submission also operates at. */
export interface Interview {
  interview_round_id: string;
  candidate_application_id: string;
  candidate_name: string;
  stage: string;
  status: string;
  scheduled_at: string | null;
}

export function useInterviewList(cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.interviews, "list", cursor ?? null],
    queryFn: () =>
      http.get<CursorPage<Interview>>("/v1/interviews", { params: { cursor, limit: 20 } }),
  });
}

export function useInterview(interviewId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.interviews, interviewId],
    queryFn: () => http.get<Interview>(`/v1/interviews/${interviewId}`),
    enabled: Boolean(interviewId),
  });
}

/** Mirrors HrAutomation.Application.Contracts.InterviewDtos.ScheduleInterviewRequest exactly. */
export interface ScheduleInterviewInput {
  candidate_application_id: string;
  interview_round_definition_id: string;
  scheduled_start_utc: string;
  scheduled_end_utc: string;
  time_zone_id?: string;
  location_or_link?: string;
  panel_user_id?: string;
}

export function useScheduleInterview() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: ScheduleInterviewInput) => http.post("/v1/interviews", input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.interviews] });
    },
  });
}

export interface SubmitFeedbackInput {
  outcome: "select" | "reject";
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
      http.post(`/v1/interviews/${interviewId}/feedback`, {
        outcome: input.outcome,
        communication_score: input.communicationScore,
        technical_score: input.technicalScore,
        notes: input.notes,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.interviews] });
    },
  });
}
