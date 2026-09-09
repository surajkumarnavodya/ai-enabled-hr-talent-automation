import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";

/**
 * TODO(api-contract): no dedicated dashboard-summary endpoint exists on
 * HrAutomation.Api yet. This hook targets a placeholder route; see
 * docs/04-api/frontend-api-integration.md "First backend endpoints needed"
 * for the aggregate endpoint this should call once available. Backed by an
 * MSW handler for local development in the meantime (src/mocks/handlers).
 */
export interface DashboardSummary {
  activeTans: number;
  candidatesAwaitingReview: number;
  interviewsScheduledToday: number;
  pendingInterviewFeedback: number;
  pendingApprovals: number;
  offersPendingAcceptance: number;
  greenFormsPending: number;
  highSeverityDiscrepancies: number;
  employeeConversionsPending: number;
  slaBreaches: number;
}

export function useDashboardSummary() {
  return useQuery({
    queryKey: [QUERY_KEYS.admin, "dashboard-summary"],
    queryFn: () => http.get<DashboardSummary>("/v1/dashboard/summary"),
  });
}
