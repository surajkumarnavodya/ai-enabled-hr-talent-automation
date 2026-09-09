import { http, HttpResponse } from "msw";
import { mockOffers } from "@/mocks/data/workflow";
import type { Offer } from "@/types/workflow";

let offers = [...mockOffers];

export const offerHandlers = [
  http.get("/api/v1/offers", () => HttpResponse.json(offers)),

  http.get("/api/v1/offers/:offerId", ({ params }) => {
    const offer = offers.find((o) => o.id === params.offerId);
    if (!offer) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(offer);
  }),

  http.post("/api/v1/applications/:applicationId/offers", async ({ request, params }) => {
    const body = (await request.json()) as { compensationRef: string; templateVersion: string };
    const newOffer: Offer = {
      id: `offer-${Date.now()}`,
      applicationId: params.applicationId as string,
      status: "drafted",
      compensationRef: body.compensationRef,
      templateVersion: body.templateVersion,
    };
    offers = [...offers, newOffer];
    return HttpResponse.json(newOffer, { status: 201 });
  }),

  http.post("/api/v1/offers/:offerId/approve", ({ params }) => {
    offers = offers.map((o) => (o.id === params.offerId ? { ...o, status: "approved" } : o));
    return HttpResponse.json(offers.find((o) => o.id === params.offerId));
  }),

  http.post("/api/v1/offers/:offerId/send", ({ params }) => {
    offers = offers.map((o) => (o.id === params.offerId ? { ...o, status: "sent" } : o));
    return HttpResponse.json(offers.find((o) => o.id === params.offerId));
  }),
];
