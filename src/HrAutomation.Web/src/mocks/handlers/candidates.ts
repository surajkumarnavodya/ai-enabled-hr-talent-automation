import { http, HttpResponse, delay } from "msw";
import { mockCandidates } from "@/mocks/data/candidates";
import { mockAgentActionResponse } from "@/mocks/data/agentActionResponse";
import type { Candidate } from "@/types/workflow";
import type { CursorPage } from "@/types/api";

export const candidateHandlers = [
  http.get("/api/v1/candidates", async () => {
    await delay(150);
    const page: CursorPage<Candidate> = { items: mockCandidates, next_cursor: null };
    return HttpResponse.json(page);
  }),

  http.get("/api/v1/candidates/:candidateId", ({ params }) => {
    const candidate = mockCandidates.find((c) => c.candidate_id === params.candidateId);
    if (!candidate) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(candidate);
  }),

  // Matches the real single-file endpoint (CandidatesController.UploadCv).
  http.post("/api/v1/candidates/cvs", async () => {
    await delay(300);
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "upload_cv",
        current_state: "N/A",
        candidate_id: `cand-${Date.now()}`,
      })
    );
  }),
];
