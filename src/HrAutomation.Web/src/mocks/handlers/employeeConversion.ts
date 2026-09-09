import { http, HttpResponse } from "msw";
import { mockConversionCandidates } from "@/mocks/data/workflow";
import { mockAgentActionResponse } from "@/mocks/data/agentActionResponse";

export const employeeConversionHandlers = [
  http.get("/api/v1/employee-conversion", () =>
    HttpResponse.json({ items: mockConversionCandidates, next_cursor: null })
  ),
  http.get("/api/v1/employee-conversion/:applicationId", ({ params }) => {
    const item = mockConversionCandidates.find((c) => c.application_id === params.applicationId);
    if (!item) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(item);
  }),
  http.post("/api/v1/applications/:applicationId/convert-to-employee", () =>
    HttpResponse.json(
      mockAgentActionResponse({
        action: "convert_to_employee",
        current_state: "Converted",
        employee_id: "emp-0001",
        employee_number: "EMP-2026-000001",
      })
    )
  ),
];
