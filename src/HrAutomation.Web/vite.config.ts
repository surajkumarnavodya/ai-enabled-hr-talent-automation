/// <reference types="vitest/config" />
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

const rootDir = import.meta.dirname;

// See ./README.md "Development proxy" section. In dev, the browser talks to the
// Vite dev server only; Vite proxies /api/* to the real backend so we never need
// a CORS policy change on HrAutomation.Api for local development.
const API_PROXY_TARGET = process.env.VITE_API_PROXY_TARGET ?? "http://localhost:5219";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(rootDir, "./src"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: API_PROXY_TARGET,
        changeOrigin: true,
        secure: false,
      },
      // Same-origin proxy for the dev-only integration status indicator (see
      // components/common/DevIntegrationStatus.tsx) — avoids a CORS policy change on
      // HrAutomation.Api just to check reachability from the dev server.
      "/health": {
        target: API_PROXY_TARGET,
        changeOrigin: true,
        secure: false,
      },
    },
  },
  build: {
    sourcemap: true,
    outDir: "dist",
  },
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/tests/setup.ts"],
    css: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      exclude: [
        "src/api/generated/**",
        "src/mocks/**",
        "**/*.d.ts",
        "e2e/**",
      ],
    },
    exclude: ["e2e/**", "node_modules/**"],
  },
});
