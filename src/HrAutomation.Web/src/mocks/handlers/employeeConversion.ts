import { http, HttpResponse } from "msw";
import { mockConversionCandidates } from "@/mocks/data/workflow";

export const employeeConversionHandlers = [
  http.get("/api/v1/employee-conversion", () => HttpResponse.json(mockConversionCandidates)),
  http.get("/api/v1/employee-conversion/:applicationId", ({ params }) => {
    const item = mockConversionCandidates.find((c) => c.applicationId === params.applicationId);
    if (!item) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(item);
  }),
];
