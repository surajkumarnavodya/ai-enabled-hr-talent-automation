import { AlertTriangle, Lock, ShieldOff, SearchX, WifiOff } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { ApiError, isRetryableError, userSafeMessage } from "@/api/client/apiError";
import type { ApiErrorKind } from "@/api/client/apiError";

export interface ErrorStateProps {
  /**
   * The raw error (typically from TanStack Query's `error`), when available.
   * Preferred over `message` — it drives both the user-safe copy (via
   * `userSafeMessage`) and whether a Retry button makes sense at all (no
   * point retrying a 403 or a 404). Pass `message` directly only for
   * non-API-error cases (e.g. a purely local validation failure).
   */
  error?: unknown;
  /** User-safe message only — never a raw stack trace or backend exception detail. Overrides the message derived from `error`. */
  message?: string;
  onRetry?: () => void;
}

const KIND_ICON: Partial<Record<ApiErrorKind, LucideIcon>> = {
  unauthorized: Lock,
  forbidden: ShieldOff,
  not_found: SearchX,
  network_error: WifiOff,
};

export function ErrorState({ error, message, onRetry }: ErrorStateProps) {
  const resolvedMessage = message ?? (error !== undefined ? userSafeMessage(error) : undefined) ??
    "Something went wrong loading this data. Please try again.";
  const kind = error instanceof ApiError ? error.kind : undefined;
  const Icon = (kind && KIND_ICON[kind]) || AlertTriangle;
  // Retrying a 401/403/404/422 just reproduces the same outcome — only offer
  // Retry for the error kinds a retry can plausibly resolve (or when we don't
  // know the kind at all, e.g. a thrown non-ApiError).
  const canRetry = Boolean(onRetry) && (kind === undefined || isRetryableError(error) || kind === "rate_limited");

  return (
    <div
      role="alert"
      className="flex flex-col items-center justify-center rounded-lg border border-red-200 bg-red-50 p-8 text-center dark:border-red-900 dark:bg-red-950"
    >
      <Icon className="mb-3 h-8 w-8 text-status-danger" aria-hidden="true" />
      <p className="text-sm font-medium text-slate-900 dark:text-slate-100">{resolvedMessage}</p>
      {error instanceof ApiError && error.correlationId && (
        <p className="mt-1 text-xs text-slate-400">Reference: {error.correlationId}</p>
      )}
      {canRetry && (
        <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}
