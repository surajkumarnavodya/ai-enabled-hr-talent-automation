import { http, HttpResponse } from "msw";
import { mockDashboardSummary } from "@/mocks/data/workflow";

export const dashboardHandlers = [
  http.get("/api/v1/dashboard/summary", () => HttpResponse.json(mockDashboardSummary)),
];
