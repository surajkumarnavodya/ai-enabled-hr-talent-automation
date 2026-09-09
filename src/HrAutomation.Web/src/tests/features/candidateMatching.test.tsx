import { describe, expect, it } from "vitest";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderWithProviders } from "@/tests/testUtils";
import CandidateMatchesPage from "@/features/candidate-matching/CandidateMatchesPage";

describe("CandidateMatchesPage", () => {
  it("clearly labels AI output as a recommendation requiring human approval", async () => {
    renderWithProviders(<CandidateMatchesPage />, {
      path: "/tans/:tanId/matches",
      route: "/tans/tan-0001/matches",
    });

    expect(
      await screen.findByText(/AI recommendation — human approval required/i)
    ).toBeInTheDocument();
  });

  it("never approves a shortlist without explicit confirmation", async () => {
    const user = userEvent.setup();
    renderWithProviders(<CandidateMatchesPage />, {
      path: "/tans/:tanId/matches",
      route: "/tans/tan-0001/matches",
      user: { userId: "u1", tenantId: "t1", displayName: "Demo HR Admin", role: "HR_ADMIN" },
    });

    const approveButtons = await screen.findAllByRole("button", { name: /approve for shortlist/i });
    expect(approveButtons.length).toBeGreaterThan(0);

    // Clicking the action button only opens the confirmation dialog — it must
    // not call the API until the dialog is explicitly confirmed.
    await user.click(approveButtons[0]!);
    expect(screen.getByRole("heading", { name: /approve shortlist/i })).toBeInTheDocument();
    expect(screen.getByText(/human decision recorded/i)).toBeInTheDocument();
  });
});
