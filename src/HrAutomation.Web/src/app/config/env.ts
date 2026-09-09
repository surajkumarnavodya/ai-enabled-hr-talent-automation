/**
 * Single chokepoint for reading `import.meta.env`. Nothing else in the app
 * should reference `import.meta.env` directly — that keeps env access
 * type-checked, validated at boot, and easy to audit for accidental secret
 * exposure (anything prefixed VITE_ is bundled into public JS output).
 */

/** Exported for a direct unit test of the MSW-default-off behavior — see
 * tests/unit/env.test.ts. Not meant to be imported by feature code. */
export function readBool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) return fallback;
  return value === "true" || value === "1";
}

function readNumber(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const env = {
  appEnv: import.meta.env.VITE_APP_ENV || "dev",
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || "/api",
  apiTimeoutMs: readNumber(import.meta.env.VITE_API_TIMEOUT_MS, 15000),
  authMode: (import.meta.env.VITE_AUTH_MODE || "mock") as "mock" | "devToken" | "oidc",
  oidcAuthority: import.meta.env.VITE_OIDC_AUTHORITY || "",
  oidcClientId: import.meta.env.VITE_OIDC_CLIENT_ID || "",
  oidcRedirectUri: import.meta.env.VITE_OIDC_REDIRECT_URI || "",
  // Default OFF: real runtime must hit the real API unless a developer explicitly opts into
  // isolated mock-mode UI development. See CLAUDE.md / docs/05-security-governance/frontend-security.md.
  enableMsw: readBool(import.meta.env.VITE_ENABLE_MSW, false),
  defaultTimeZone: import.meta.env.VITE_DEFAULT_TIMEZONE || "UTC",
  otelExporterEndpoint: import.meta.env.VITE_OTEL_EXPORTER_OTLP_ENDPOINT || "",
} as const;
