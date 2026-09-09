/**
 * Centralized error mapping. Every API error surfaced to the UI goes through
 * this shape — components never render a raw backend stack trace or
 * exception message. See docs/05-security-governance/frontend-security.md.
 */
export type ApiErrorKind =
  | "unauthorized" // 401
  | "forbidden" // 403
  | "not_found" // 404
  | "conflict" // 409
  | "validation" // 422
  | "rate_limited" // 429
  | "server_error" // 5xx
  | "network_error" // no response reached the server
  | "unknown";

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly status?: number;
  readonly correlationId?: string;
  /** RFC 7807 field-level validation errors, if the server returned any (422 responses). */
  readonly fieldErrors?: Record<string, string>;

  constructor(
    kind: ApiErrorKind,
    message: string,
    options?: { status?: number; correlationId?: string; fieldErrors?: Record<string, string> }
  ) {
    super(message);
    this.name = "ApiError";
    this.kind = kind;
    this.status = options?.status;
    this.correlationId = options?.correlationId;
    this.fieldErrors = options?.fieldErrors;
  }
}

const USER_SAFE_MESSAGES: Record<ApiErrorKind, string> = {
  unauthorized: "Your session has expired. Please sign in again.",
  forbidden: "You don't have permission to perform this action.",
  not_found: "The requested item could not be found.",
  conflict: "This item was changed by someone else. Please refresh and try again.",
  validation: "Some of the information provided is invalid. Please review and try again.",
  rate_limited: "Too many requests. Please wait a moment and try again.",
  server_error: "Something went wrong on our end. Please try again shortly.",
  network_error: "Unable to reach the server. Check your connection and try again.",
  unknown: "An unexpected error occurred. Please try again.",
};

export function userSafeMessage(error: unknown): string {
  if (error instanceof ApiError) return USER_SAFE_MESSAGES[error.kind];
  return USER_SAFE_MESSAGES.unknown;
}

export function kindFromStatus(status: number | undefined): ApiErrorKind {
  if (status === undefined) return "network_error";
  if (status === 401) return "unauthorized";
  if (status === 403) return "forbidden";
  if (status === 404) return "not_found";
  if (status === 409) return "conflict";
  if (status === 422) return "validation";
  if (status === 429) return "rate_limited";
  if (status >= 500) return "server_error";
  return "unknown";
}

/** Only GET-style, idempotent reads are ever safe to retry automatically. */
export function isRetryableError(error: unknown): boolean {
  if (!(error instanceof ApiError)) return false;
  return error.kind === "network_error" || error.kind === "server_error";
}
