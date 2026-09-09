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
      className="flex flex-col items-center justify-center rounded-lg border border-status-danger/20 bg-status-danger-tint p-8 text-center dark:bg-status-danger-tint-dark"
    >
      <div className="mb-3 rounded-full bg-surface-raised p-2.5 shadow-sm">
        <Icon className="h-6 w-6 text-status-danger" aria-hidden="true" />
      </div>
      <p className="text-sm font-medium text-primary">{resolvedMessage}</p>
      {error instanceof ApiError && error.correlationId && (
        <p className="mt-1 text-xs text-tertiary">Reference: {error.correlationId}</p>
      )}
      {canRetry && (
        <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}
