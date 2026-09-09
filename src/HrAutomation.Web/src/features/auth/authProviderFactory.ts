import type { AuthProvider } from "@/types/auth";
import { appConfig } from "@/app/config/appConfig";
import { createMockAuthProvider } from "@/features/auth/mockAuthProvider";
import { createDevTokenAuthProvider } from "@/features/auth/devTokenAuthProvider";
import { createOidcAuthProvider } from "@/features/auth/oidcAuthProvider";

/**
 * The single module-level auth provider instance, selected by
 * VITE_AUTH_MODE. Exported so both the React auth context (AuthContext.tsx)
 * and the non-React API client interceptor (api/client/apiClient.ts) can read
 * the current access token without creating a dependency from the API layer
 * on React itself.
 */
export const activeAuthProvider: AuthProvider = (() => {
  switch (appConfig.authMode) {
    case "oidc":
      return createOidcAuthProvider();
    case "devToken":
      return createDevTokenAuthProvider();
    default:
      return createMockAuthProvider();
  }
})();
