import { useState, type ReactNode } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { isRetryableError } from "@/api/client/apiError";

/**
 * One QueryClient per app instance. Retry policy: only safe, idempotent GET
 * requests are retried automatically (see api/client/apiClient.ts and
 * lib/isRetryableError logic) — mutations never auto-retry, per CLAUDE.md
 * state-management rules.
 */
export function QueryProvider({ children }: { children: ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            retry: (failureCount, error) => failureCount < 2 && isRetryableError(error),
            staleTime: 30_000,
            refetchOnWindowFocus: false,
          },
          mutations: {
            retry: false,
          },
        },
      })
  );

  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
