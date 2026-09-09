import type { ReactElement, ReactNode } from "react";
import { render } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { AuthContext, type AuthContextValue } from "@/features/auth/AuthContext";
import type { AuthenticatedUser } from "@/types/auth";

const noopAsync = async () => {};

export function makeAuthValue(user: AuthenticatedUser | null): AuthContextValue {
  return {
    status: user ? "authenticated" : "unauthenticated",
    user,
    error: null,
    login: noopAsync,
    logout: noopAsync,
  };
}

/**
 * Shared test-only provider wrapper: fresh QueryClient (no retries) + a
 * fixed AuthContext value (bypassing the real mock auth provider singleton
 * so tests don't leak login state into one another) + MemoryRouter.
 *
 * Pass `path` (a route pattern like "/tans/:tanId/matches") together with
 * `route` (the concrete entry like "/tans/tan-0001/matches") when the
 * component under test relies on `useParams`.
 */
export function renderWithProviders(
  ui: ReactElement,
  options?: { route?: string; path?: string; user?: AuthenticatedUser | null }
) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });

  const authValue = makeAuthValue(
    options?.user ?? { userId: "u1", tenantId: "t1", displayName: "Demo User", role: "HR_ADMIN" }
  );
  const route = options?.route ?? "/";
  const path = options?.path ?? route;

  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <AuthContext.Provider value={authValue}>
          <MemoryRouter initialEntries={[route]}>
            <Routes>
              <Route path={path} element={children} />
            </Routes>
          </MemoryRouter>
        </AuthContext.Provider>
      </QueryClientProvider>
    );
  }

  return render(ui, { wrapper: Wrapper });
}
