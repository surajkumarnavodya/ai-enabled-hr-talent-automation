import { isRouteErrorResponse, useNavigate, useRouteError } from "react-router-dom";
import { AlertTriangle, SearchX } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { safeLogger } from "@/lib/safeLogger";

/**
 * React Router `errorElement` — catches router-level failures a TanStack
 * Query `isError` state never sees: unmatched routes, a component throwing
 * during render, or a lazy-loaded chunk failing to load (e.g. stale chunk
 * hash after a deploy). Ordinary API errors (401/403/404/5xx on a data
 * fetch) are handled by ErrorState instead — see api/client/apiError.ts.
 * Never shows a raw error message/stack — see
 * docs/05-security-governance/frontend-security.md.
 */
export function RouteErrorBoundary() {
  const error = useRouteError();
  const navigate = useNavigate();
  const isNotFound = isRouteErrorResponse(error) && error.status === 404;

  if (!isNotFound) {
    safeLogger.error("route error boundary", {
      message: error instanceof Error ? error.message : "unknown",
    });
  }

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center p-6 text-center">
      {isNotFound ? (
        <SearchX className="mb-3 h-10 w-10 text-status-neutral" aria-hidden="true" />
      ) : (
        <AlertTriangle className="mb-3 h-10 w-10 text-status-danger" aria-hidden="true" />
      )}
      <h1 className="mb-2 text-lg font-semibold text-slate-900 dark:text-slate-100">
        {isNotFound ? "Page not found" : "This page hit a problem"}
      </h1>
      <p className="mb-4 max-w-md text-sm text-slate-600 dark:text-slate-400">
        {isNotFound
          ? "The page you're looking for doesn't exist or may have moved."
          : "Something went wrong loading this section. You can go back to the dashboard or try again."}
      </p>
      <div className="flex gap-2">
        <Button variant="outline" onClick={() => navigate("/dashboard")}>
          Back to dashboard
        </Button>
        {!isNotFound && <Button onClick={() => window.location.reload()}>Reload</Button>}
      </div>
    </div>
  );
}
