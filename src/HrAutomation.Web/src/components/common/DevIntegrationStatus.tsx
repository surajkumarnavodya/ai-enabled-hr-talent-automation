import { useEffect, useState } from "react";
import { appConfig } from "@/app/config/appConfig";
import { useAuth } from "@/hooks/useAuth";

type ApiReachability = "checking" | "reachable" | "unreachable";

/**
 * Dev-only, non-sensitive integration status strip. Never shown in production
 * regardless of any env var (gated below), and never renders the database server
 * name, connection string, user identity details, or exception text — only a
 * reachable/unreachable boolean derived from GET /health's top-level status field,
 * and the API base URL's host (not full path, never a query string/token).
 */
export function DevIntegrationStatus() {
  const { status: authStatus } = useAuth();
  const [apiStatus, setApiStatus] = useState<ApiReachability>("checking");

  useEffect(() => {
    if (appConfig.env === "prod") return;
    let cancelled = false;

    async function checkHealth() {
      try {
        const response = await fetch("/health", { signal: AbortSignal.timeout(5000) });
        if (cancelled) return;
        setApiStatus(response.ok ? "reachable" : "unreachable");
      } catch {
        if (!cancelled) setApiStatus("unreachable");
      }
    }

    void checkHealth();
    const interval = setInterval(() => void checkHealth(), 30_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  if (appConfig.env === "prod") return null;

  const apiHost = (() => {
    try {
      return new URL(appConfig.apiBaseUrl, window.location.origin).host;
    } catch {
      return appConfig.apiBaseUrl;
    }
  })();

  const dotClass = (ok: boolean) => (ok ? "bg-status-success" : "bg-status-danger");

  return (
    <div
      role="status"
      aria-label="Development integration status"
      className="flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-subtle bg-surface-sunken px-4 py-1 text-xs text-secondary"
    >
      <span className="flex items-center gap-1.5">
        <span
          className={`h-2 w-2 rounded-full ${
            apiStatus === "checking" ? "bg-neutral-400" : dotClass(apiStatus === "reachable")
          }`}
          aria-hidden="true"
        />
        API ({apiHost}): {apiStatus}
      </span>
      <span className="flex items-center gap-1.5">
        <span
          className={`h-2 w-2 rounded-full ${appConfig.mswEnabled ? "bg-status-warning" : "bg-status-success"}`}
          aria-hidden="true"
        />
        MSW: {appConfig.mswEnabled ? "enabled (mock data)" : "disabled (real API)"}
      </span>
      <span className="flex items-center gap-1.5">
        <span
          className={`h-2 w-2 rounded-full ${dotClass(authStatus === "authenticated")}`}
          aria-hidden="true"
        />
        Auth ({appConfig.authMode}): {authStatus}
      </span>
    </div>
  );
}
