import type { InternalAxiosRequestConfig, AxiosResponse, AxiosError } from "axios";
import { activeAuthProvider } from "@/features/auth/authProviderFactory";
import { createCorrelationId, createIdempotencyKey } from "@/api/client/correlationId";
import { ApiError, kindFromStatus } from "@/api/client/apiError";
import { HEADER_CORRELATION_ID, HEADER_IDEMPOTENCY_KEY } from "@/lib/constants";
import { safeLogger } from "@/lib/safeLogger";

const SIDE_EFFECT_METHODS = new Set(["post", "patch", "put", "delete"]);

/**
 * Attaches auth, correlation ID, and (for mutating requests) an idempotency
 * key. Tenant context is deliberately NOT set here from any UI-selected
 * value — it is derived server-side from the validated bearer token/session,
 * per CLAUDE.md "do not trust UI-selected tenant values".
 */
export async function attachRequestMetadata(
  config: InternalAxiosRequestConfig
): Promise<InternalAxiosRequestConfig> {
  const token = await activeAuthProvider.getAccessToken();
  if (token) {
    config.headers.set("Authorization", `Bearer ${token}`);
  }

  config.headers.set(HEADER_CORRELATION_ID, createCorrelationId());
  config.headers.set("Accept", "application/json");

  const method = (config.method ?? "get").toLowerCase();
  if (SIDE_EFFECT_METHODS.has(method) && !config.headers.has(HEADER_IDEMPOTENCY_KEY)) {
    config.headers.set(HEADER_IDEMPOTENCY_KEY, createIdempotencyKey());
  }

  return config;
}

export function onResponseSuccess(response: AxiosResponse): AxiosResponse {
  return response;
}

/** Converts any axios failure into our centralized ApiError shape (RFC 7807 aware). */
export function onResponseError(error: AxiosError): Promise<never> {
  const status = error.response?.status;
  const correlationId = error.response?.headers?.[HEADER_CORRELATION_ID.toLowerCase()] as
    string | undefined;

  const body = error.response?.data as
    { title?: string; detail?: string; errors?: Record<string, string[]> } | undefined;

  const fieldErrors: Record<string, string> | undefined = body?.errors
    ? Object.fromEntries(Object.entries(body.errors).map(([field, msgs]) => [field, msgs[0] ?? ""]))
    : undefined;

  const kind = error.response ? kindFromStatus(status) : "network_error";

  safeLogger.warn("api request failed", {
    status,
    kind,
    correlationId,
    url: error.config?.url,
    method: error.config?.method,
  });

  return Promise.reject(
    new ApiError(kind, body?.detail ?? body?.title ?? error.message, {
      status,
      correlationId,
      fieldErrors,
    })
  );
}
