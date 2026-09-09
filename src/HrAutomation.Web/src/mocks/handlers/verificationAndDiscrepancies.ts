import { http, HttpResponse } from "msw";
import { mockVerificationQueue, mockDiscrepancies } from "@/mocks/data/workflow";

let discrepancies = [...mockDiscrepancies];

export const verificationHandlers = [
  http.get("/api/v1/verification", () =>
    HttpResponse.json({ items: mockVerificationQueue, next_cursor: null })
  ),
  http.get("/api/v1/verification/:applicationId", ({ params }) => {
    const item = mockVerificationQueue.find((v) => v.application_id === params.applicationId);
    if (!item) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(item);
  }),
];

export const discrepancyHandlers = [
  http.get("/api/v1/discrepancies", () =>
    HttpResponse.json({ items: discrepancies, next_cursor: null })
  ),
  http.get("/api/v1/discrepancies/:discrepancyId", ({ params }) => {
    const item = discrepancies.find((d) => d.id === params.discrepancyId);
    if (!item) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(item);
  }),
  http.post("/api/v1/discrepancies/:discrepancyId/reupload-request", () => {
    return HttpResponse.json({ status: "reupload_requested" });
  }),
  http.post("/api/v1/discrepancies/:discrepancyId/resolve", ({ params }) => {
    discrepancies = discrepancies.map((d) =>
      d.id === params.discrepancyId ? { ...d, status: "CLOSED" } : d
    );
    return HttpResponse.json(discrepancies.find((d) => d.id === params.discrepancyId));
  }),
];
