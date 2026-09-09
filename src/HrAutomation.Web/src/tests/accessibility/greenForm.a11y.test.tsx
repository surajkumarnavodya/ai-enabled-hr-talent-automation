import { describe, expect, it } from "vitest";
import { axe } from "vitest-axe";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { render } from "@testing-library/react";
import GreenFormPage from "@/features/green-form/GreenFormPage";

/**
 * Critical accessibility check for the candidate-facing Green Form — this is
 * the one page in the platform used by people outside the organization, so
 * it gets a dedicated axe pass per docs/09-quality-evaluation/frontend-test-strategy.md.
 */
describe("GreenFormPage accessibility", () => {
  it("has no detectable axe violations once loaded", async () => {
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

    const { container, findByRole } = render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={["/green-form/demo-token-0001"]}>
          <Routes>
            <Route path="/green-form/:token" element={<GreenFormPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    );

    await findByRole("heading", { name: /onboarding — green form/i });

    const results = await axe(container);
    expect(results.violations).toEqual([]);
  });
});
