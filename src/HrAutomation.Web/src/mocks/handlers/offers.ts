import { http, HttpResponse } from "msw";
import { mockOffers } from "@/mocks/data/workflow";
import { mockAgentActionResponse } from "@/mocks/data/agentActionResponse";

let offers = [...mockOffers];

export const offerHandlers = [
  http.get("/api/v1/offers", () => HttpResponse.json({ items: offers, next_cursor: null })),

  http.get("/api/v1/offers/:offerId", ({ params }) => {
    const offer = offers.find((o) => o.offer_id === params.offerId);
    if (!offer) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(offer);
  }),

  http.post("/api/v1/offers", async ({ request }) => {
    const body = (await request.json()) as { candidate_application_id: string };
    const newOffer = {
      offer_id: `offer-${Date.now()}`,
      candidate_application_id: body.candidate_application_id,
      offer_number: `OFR-${Date.now()}`,
      status: "PendingApproval",
      row_version: "AAAAAAAAB9E=",
    };
    offers = [...offers, newOffer];
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "create_offer",
        current_state: "PendingApproval",
        offer_id: newOffer.offer_id,
        application_id: newOffer.candidate_application_id,
      }),
      { status: 201 }
    );
  }),

  http.post("/api/v1/offers/:offerId/approve", ({ params }) => {
    offers = offers.map((o) =>
      o.offer_id === params.offerId ? { ...o, status: "Approved" } : o
    );
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "approve_offer",
        current_state: "Approved",
        offer_id: params.offerId as string,
      })
    );
  }),

  http.post("/api/v1/offers/:offerId/send", ({ params }) => {
    offers = offers.map((o) => (o.offer_id === params.offerId ? { ...o, status: "Sent" } : o));
    return HttpResponse.json(
      mockAgentActionResponse({
        action: "send_offer",
        current_state: "Sent",
        offer_id: params.offerId as string,
      })
    );
  }),
];
