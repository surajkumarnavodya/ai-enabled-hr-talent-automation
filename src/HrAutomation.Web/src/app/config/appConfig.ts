import { env } from "@/app/config/env";

/**
 * Derived, ready-to-consume application configuration. Prefer importing this
 * over `env` directly in feature code — it's the place to add computed or
 * validated values without touching every call site.
 */
export const appConfig = {
  env: env.appEnv,
  apiBaseUrl: env.apiBaseUrl,
  apiTimeoutMs: env.apiTimeoutMs,
  authMode: env.authMode,
  oidc: {
    authority: env.oidcAuthority,
    clientId: env.oidcClientId,
    redirectUri: env.oidcRedirectUri,
  },
  mswEnabled: env.enableMsw && env.appEnv !== "prod",
  defaultTimeZone: env.defaultTimeZone,
  otelExporterEndpoint: env.otelExporterEndpoint || null,
} as const;
