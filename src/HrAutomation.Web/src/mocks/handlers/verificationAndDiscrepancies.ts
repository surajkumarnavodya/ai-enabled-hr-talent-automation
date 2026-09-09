import { http, HttpResponse } from "msw";
import { mockVerificationQueue, mockDiscrepancies } from "@/mocks/data/workflow";

let discrepancies = [...mockDiscrepancies];

export const verificationHandlers = [
  http.get("/api/v1/verification", () => HttpResponse.json(mockVerificationQueue)),
  http.get("/api/v1/verification/:applicationId", ({ params }) => {
    const item = mockVerificationQueue.find((v) => v.applicationId === params.applicationId);
    if (!item) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(item);
  }),
];

export const discrepancyHandlers = [
  http.get("/api/v1/discrepancies", () => HttpResponse.json(discrepancies)),
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
      d.id === params.discrepancyId ? { ...d, status: "resolved" } : d
    );
    return HttpResponse.json(discrepancies.find((d) => d.id === params.discrepancyId));
  }),
];
