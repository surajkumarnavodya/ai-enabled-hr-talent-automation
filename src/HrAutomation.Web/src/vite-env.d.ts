/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_ENV: "dev" | "test" | "staging" | "prod";
  readonly VITE_API_BASE_URL: string;
  readonly VITE_API_TIMEOUT_MS: string;
  readonly VITE_AUTH_MODE: "mock" | "oidc";
  readonly VITE_OIDC_AUTHORITY: string;
  readonly VITE_OIDC_CLIENT_ID: string;
  readonly VITE_OIDC_REDIRECT_URI: string;
  readonly VITE_ENABLE_MSW: string;
  readonly VITE_DEFAULT_TIMEZONE: string;
  readonly VITE_OTEL_EXPORTER_OTLP_ENDPOINT: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
