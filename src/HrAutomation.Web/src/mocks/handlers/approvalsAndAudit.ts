import { http, HttpResponse } from "msw";
import { mockPendingApprovals, mockAuditLog } from "@/mocks/data/workflow";

let approvals = [...mockPendingApprovals];

export const approvalHandlers = [
  http.get("/api/v1/approvals", () => HttpResponse.json(approvals)),
  http.post("/api/v1/approvals/:id/decision", ({ params }) => {
    approvals = approvals.filter((a) => a.id !== params.id);
    return HttpResponse.json({ status: "recorded" });
  }),
];

export const auditHandlers = [http.get("/api/v1/audit-log", () => HttpResponse.json(mockAuditLog))];
