import { RouterProvider as ReactRouterProvider } from "react-router-dom";
import { router as browserRouter, type AppRouter } from "@/app/router/routes";

export interface RouterProviderProps {
  /** Injectable for tests — pass a `createMemoryRouter` instance instead of the real browser router. */
  router?: AppRouter;
}

export function RouterProvider({ router = browserRouter }: RouterProviderProps) {
  return (
    <ReactRouterProvider
      router={router}
      // Without this, a Link click that triggers a lazy/Suspense route
      // transition can crash with "A component suspended while responding
      // to synchronous input" under React 18 — this wraps navigation
      // updates in React.startTransition, the React Router v7 default.
      future={{ v7_startTransition: true }}
    />
  );
}
