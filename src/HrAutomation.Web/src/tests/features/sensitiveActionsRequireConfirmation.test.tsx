import { describe, expect, it, vi } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { server } from "@/mocks/server";
import { renderWithProviders } from "@/tests/testUtils";
import OfferDetailPage from "@/features/offers/OfferDetailPage";
import EmployeeConversionDetailPage from "@/features/employee-conversion/EmployeeConversionDetailPage";

describe("Offer send requires explicit confirmation", () => {
  it("does not call the send-offer endpoint until the confirmation dialog is accepted", async () => {
    const sendSpy = vi.fn();
    server.use(
      http.get("/api/v1/offers/:offerId", () =>
        HttpResponse.json({
          id: "offer-test-0001",
          applicationId: "app-0001",
          status: "approved",
          compensationRef: "comp-ref-demo",
          templateVersion: "offer-template-v2",
        })
      ),
      http.post("/api/v1/offers/:offerId/send", () => {
        sendSpy();
        return HttpResponse.json({ status: "sent" });
      })
    );

    const user = userEvent.setup();
    renderWithProviders(<OfferDetailPage />, {
      path: "/offers/:offerId",
      route: "/offers/offer-test-0001",
    });

    const sendButton = await screen.findByRole("button", { name: /send offer/i });
    await user.click(sendButton);

    // Dialog is open, but the API must not have been called yet.
    expect(screen.getByRole("heading", { name: /send offer/i })).toBeInTheDocument();
    expect(sendSpy).not.toHaveBeenCalled();

    // Two "Send offer" buttons now exist (the page action + the dialog's
    // confirm button) — the confirm button is the one rendered last.
    const sendButtons = screen.getAllByRole("button", { name: /send offer/i });
    await user.click(sendButtons[sendButtons.length - 1]!);
    await waitFor(() => expect(sendSpy).toHaveBeenCalledTimes(1));
  });
});

describe("Employee conversion requires explicit confirmation and eligibility", () => {
  it("disables Create Employee ID until the checklist is eligible", async () => {
    server.use(
      http.get("/api/v1/employee-conversion/:applicationId", () =>
        HttpResponse.json({
          applicationId: "app-ineligible",
          candidateName: "Demo Candidate",
          eligible: false,
          checklist: [{ check: "Documents verified", status: "pending" }],
        })
      )
    );

    renderWithProviders(<EmployeeConversionDetailPage />, {
      path: "/employee-conversion/:applicationId",
      route: "/employee-conversion/app-ineligible",
    });

    const button = await screen.findByRole("button", { name: /create employee id/i });
    expect(button).toBeDisabled();
  });

  it("only creates the employee after explicit confirmation when eligible", async () => {
    const convertSpy = vi.fn();
    server.use(
      http.get("/api/v1/employee-conversion/:applicationId", () =>
        HttpResponse.json({
          applicationId: "app-eligible",
          candidateName: "Demo Candidate",
          eligible: true,
          checklist: [{ check: "Documents verified", status: "pass" }],
        })
      ),
      http.post("/api/v1/applications/:applicationId/employee-conversion", () => {
        convertSpy();
        return HttpResponse.json({ employeeId: "emp-1", employeeNumber: "EMP-2026-000001" });
      })
    );

    const user = userEvent.setup();
    renderWithProviders(<EmployeeConversionDetailPage />, {
      path: "/employee-conversion/:applicationId",
      route: "/employee-conversion/app-eligible",
      user: { userId: "u1", tenantId: "t1", displayName: "Demo HR Admin", role: "HR_ADMIN" },
    });

    const button = await screen.findByRole("button", { name: /create employee id/i });
    expect(button).toBeEnabled();

    await user.click(button);
    expect(convertSpy).not.toHaveBeenCalled();

    // Two "Create Employee ID" buttons now exist (the page action + the
    // dialog's confirm button) — the confirm button is rendered last.
    const confirmButtons = screen.getAllByRole("button", { name: /create employee id/i });
    await user.click(confirmButtons[confirmButtons.length - 1]!);
    await waitFor(() => expect(convertSpy).toHaveBeenCalledTimes(1));
  });
});
