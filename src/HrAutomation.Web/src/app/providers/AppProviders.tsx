import { ThemeProvider } from "@/app/providers/ThemeProvider";
import { QueryProvider } from "@/app/providers/QueryProvider";
import { AuthProvider } from "@/features/auth/AuthContext";
import { RouterProvider } from "@/app/providers/RouterProvider";
import type { AppRouter } from "@/app/router/routes";

export interface AppProvidersProps {
  /** Injectable for tests — see app/providers/RouterProvider.tsx. */
  router?: AppRouter;
}

/**
 * Single composition root for every app-wide provider. Order matters:
 * Theme has no dependencies; QueryProvider must wrap anything using
 * TanStack Query hooks; AuthProvider must wrap the router since route
 * guards read auth state; RouterProvider is innermost as it renders the
 * actual page tree.
 */
export function AppProviders({ router }: AppProvidersProps) {
  return (
    <ThemeProvider>
      <QueryProvider>
        <AuthProvider>
          <RouterProvider router={router} />
        </AuthProvider>
      </QueryProvider>
    </ThemeProvider>
  );
}
