import { RouterProvider as ReactRouterProvider } from "react-router-dom";
import { router as browserRouter, type AppRouter } from "@/app/router/routes";

export interface RouterProviderProps {
  /** Injectable for tests — pass a `createMemoryRouter` instance instead of the real browser router. */
  router?: AppRouter;
}

export function RouterProvider({ router = browserRouter }: RouterProviderProps) {
  // Navigation updates wrap in React.startTransition unconditionally as of
  // React Router v7 (previously opt-in via the `v7_startTransition` future
  // flag on v6) — no `future` prop to set here anymore.
  return <ReactRouterProvider router={router} />;
}
