import axios, { type AxiosRequestConfig } from "axios";
import { appConfig } from "@/app/config/appConfig";
import {
  attachRequestMetadata,
  onResponseSuccess,
  onResponseError,
} from "@/api/client/requestInterceptors";

/**
 * Single Axios instance for all HrAutomation.Api calls. Do not create
 * ad-hoc axios/fetch calls elsewhere — every request must go through this
 * client so auth, correlation IDs, idempotency keys, and error mapping are
 * applied consistently. See docs/04-api/frontend-api-integration.md.
 *
 * baseURL comes from VITE_API_BASE_URL (see app/config/env.ts) and defaults
 * to same-origin "/api", which the Vite dev server proxies to the real
 * backend (see vite.config.ts) — this avoids needing a CORS policy change on
 * HrAutomation.Api for local development.
 */
export const apiClient = axios.create({
  baseURL: appConfig.apiBaseUrl,
  timeout: appConfig.apiTimeoutMs,
  // Enables cookie-based (BFF) auth sessions when the chosen auth provider
  // uses one; harmless no-op for bearer-token auth. Never combine with a
  // wildcard CORS origin on the backend.
  withCredentials: appConfig.authMode === "oidc",
});

apiClient.interceptors.request.use(attachRequestMetadata);
apiClient.interceptors.response.use(onResponseSuccess, onResponseError);

/**
 * Thin, typed wrappers so call sites don't repeat `.data` unwrapping. Pass an
 * AbortSignal via `config.signal` (TanStack Query provides one per query/mutation)
 * to support cancellation.
 */
export const http = {
  get: <T>(url: string, config?: AxiosRequestConfig) =>
    apiClient.get<T>(url, config).then((r) => r.data),
  post: <T>(url: string, body?: unknown, config?: AxiosRequestConfig) =>
    apiClient.post<T>(url, body, config).then((r) => r.data),
  patch: <T>(url: string, body?: unknown, config?: AxiosRequestConfig) =>
    apiClient.patch<T>(url, body, config).then((r) => r.data),
  put: <T>(url: string, body?: unknown, config?: AxiosRequestConfig) =>
    apiClient.put<T>(url, body, config).then((r) => r.data),
  delete: <T>(url: string, config?: AxiosRequestConfig) =>
    apiClient.delete<T>(url, config).then((r) => r.data),
};
