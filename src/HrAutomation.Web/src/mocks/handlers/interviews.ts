import { http, HttpResponse } from "msw";
import { mockInterviews } from "@/mocks/data/workflow";

export const interviewHandlers = [
  http.get("/api/v1/interviews", () => HttpResponse.json(mockInterviews)),

  http.get("/api/v1/interviews/:interviewId", ({ params }) => {
    const interview = mockInterviews.find((i) => i.id === params.interviewId);
    if (!interview) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(interview);
  }),

  http.post("/api/v1/interviews/:interviewId/feedback", () => {
    return HttpResponse.json({ status: "recorded" }, { status: 201 });
  }),
];
