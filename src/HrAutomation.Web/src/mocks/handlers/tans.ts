import { http, HttpResponse } from "msw";
import { mockTans, mockMatchResults } from "@/mocks/data/tans";
import { mockAgentActionResponse } from "@/mocks/data/agentActionResponse";
import type { Tan } from "@/types/workflow";
import type { CursorPage } from "@/types/api";

let tans = [...mockTans];

export const tanHandlers = [
  http.get("/api/v1/tans", () => {
    const page: CursorPage<Tan> = { items: tans, next_cursor: null };
    return HttpResponse.json(page);
  }),

  http.get("/api/v1/tans/:tanId", ({ params }) => {
    const tan = tans.find((t) => t.tan_id === params.tanId);
    if (!tan) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(tan);
  }),

  http.post("/api/v1/tans", async ({ request }) => {
    const body = (await request.json()) as { title: string };
    const newTan: Tan = {
      tan_id: `tan-${Date.now()}`,
      tan_number: `TAN-2026-${String(tans.length + 125).padStart(6, "0")}`,
      title: body.title,
      location: "",
      grade: "",
      status: "PendingApproval",
      row_version: "AAAAAAAAAAA=",
    };
    tans = [...tans, newTan];
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "create_tan",
        current_state: "PendingApproval",
        tan_id: newTan.tan_id,
      }),
      { status: 201 }
    );
  }),

  http.post("/api/v1/tans/:tanId/approve", ({ params }) => {
    tans = tans.map((t) => (t.tan_id === params.tanId ? { ...t, status: "Approved" } : t));
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "approve_tan",
        current_state: "Approved",
        tan_id: params.tanId as string,
      })
    );
  }),

  http.get("/api/v1/tans/:tanId/matches", ({ params }) => {
    return HttpResponse.json(mockMatchResults[params.tanId as string] ?? []);
  }),
];
