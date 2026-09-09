import { http, HttpResponse } from "msw";

export const applicationHandlers = [
  http.post("/api/v1/applications/:applicationId/shortlist-approval", () => {
    return HttpResponse.json({ status: "shortlist_approved" });
  }),
  http.post("/api/v1/applications/:applicationId/employee-conversion", ({ params }) => {
    return HttpResponse.json({
      employeeId: `emp-${params.applicationId}`,
      employeeNumber: "EMP-2026-004521",
    });
  }),
];
