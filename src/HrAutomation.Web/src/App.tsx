import { AppProviders } from "@/app/providers/AppProviders";
import { RootErrorBoundary } from "@/components/common/RootErrorBoundary";
import type { AppRouter } from "@/app/router/routes";

export interface AppProps {
  /** Injectable for tests — see app/providers/RouterProvider.tsx. */
  router?: AppRouter;
}

export default function App({ router }: AppProps) {
  return (
    <RootErrorBoundary>
      <AppProviders router={router} />
    </RootErrorBoundary>
  );
}
