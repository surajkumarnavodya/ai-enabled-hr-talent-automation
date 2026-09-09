/**
 * Generates a client-side correlation ID for every outbound request. The
 * backend's CorrelationIdMiddleware (HrAutomation.Api) echoes whatever value
 * it receives in the `X-Correlation-Id` header back on the response and
 * threads it through server-side tracing — see docs/04-api/frontend-api-integration.md.
 */
export function createCorrelationId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  // Fallback for environments without crypto.randomUUID (older browsers / some test runners).
  return `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Idempotency keys are generated per logical user action (not per retry) for
 * every POST/PATCH/PUT/DELETE with a side effect, matching HrAutomation.Api's
 * IdempotencyKeyMiddleware contract on the `Idempotency-Key` header.
 */
export function createIdempotencyKey(): string {
  return createCorrelationId();
}
