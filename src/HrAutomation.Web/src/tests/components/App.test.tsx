import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { createMemoryRouter } from "react-router-dom";
import App from "@/App";
import { routeObjects } from "@/app/router/routes";

describe("Application bootstrapping", () => {
  it("renders the full provider tree and route table without crashing", async () => {
    // Deliberately start on a route that requires no client-side redirect.
    // React Router's data routers (createBrowserRouter/createMemoryRouter)
    // build an internal Request on every router.navigate() call, and under
    // Vitest's jsdom environment that Request's AbortSignal comes from a
    // different realm than the one msw/node's interceptors expect — a known
    // jsdom + data-router + MSW incompatibility, not a bug in this app.
    // Redirect behavior itself is covered separately in
    // tests/components/ProtectedRoute.test.tsx using the plain (non-data)
    // router API, which isn't affected.
    const memoryRouter = createMemoryRouter(routeObjects, { initialEntries: ["/login"] });

    render(<App router={memoryRouter} />);

    expect(await screen.findByText(/HR Automation Platform/i)).toBeInTheDocument();
  });
});
