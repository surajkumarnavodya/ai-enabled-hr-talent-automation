import { http, HttpResponse } from "msw";
import { mockGreenForm } from "@/mocks/data/workflow";

export const greenFormHandlers = [
  http.get("/api/v1/green-forms/by-token/:token", () => HttpResponse.json(mockGreenForm)),
  http.get("/api/v1/green-forms/submission/:submissionId", () => HttpResponse.json(mockGreenForm)),
  http.post("/api/v1/green-forms/by-token/:token/submissions", () => {
    return HttpResponse.json({ status: "submitted" }, { status: 202 });
  }),
];
