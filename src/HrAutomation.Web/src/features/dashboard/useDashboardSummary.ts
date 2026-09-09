import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";

/** Mirrors HrAutomation.Application.Contracts.DashboardDtos.DashboardSummaryDto exactly.
 * Every field is a real, live-computed count — sla_breaches is always 0 since no SLA
 * policy/tracking mechanism exists in this schema yet (see the DTO's own doc comment). */
export interface DashboardSummary {
  active_tans: number;
  candidates_awaiting_review: number;
  interviews_scheduled_today: number;
  pending_interview_feedback: number;
  pending_approvals: number;
  offers_pending_acceptance: number;
  green_forms_pending: number;
  high_severity_discrepancies: number;
  employee_conversions_pending: number;
  sla_breaches: number;
}

export function useDashboardSummary() {
  return useQuery({
    queryKey: [QUERY_KEYS.admin, "dashboard-summary"],
    queryFn: () => http.get<DashboardSummary>("/v1/dashboard/summary"),
  });
}
