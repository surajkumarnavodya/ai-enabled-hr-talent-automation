import type { AuthProvider, AuthenticatedUser } from "@/types/auth";
import { appConfig } from "@/app/config/appConfig";
import { safeLogger } from "@/lib/safeLogger";

/**
 * Production auth provider abstraction — NOT YET IMPLEMENTED.
 *
 * This is intentionally a stub. Before enabling VITE_AUTH_MODE=oidc, implement
 * ONE of the two patterns below (see docs/05-security-governance/frontend-security.md
 * "Authentication implementation options"):
 *
 *   1. OAuth 2.1 / OIDC Authorization Code + PKCE, handled by a vetted client
 *      library (e.g. oidc-client-ts). Access/refresh tokens must be kept in
 *      that library's in-memory token store, never localStorage/sessionStorage.
 *
 *   2. Backend-for-Frontend (BFF) pattern (preferred where the backend
 *      architecture supports it): the browser never sees a token at all — the
 *      BFF sets an HttpOnly, Secure, SameSite=Strict session cookie, and
 *      `getAccessToken()` below returns null because the browser relies on
 *      `credentials: "include"` cookie auth instead (see api/client/apiClient.ts).
 *
 * Do not implement a third option that stores a raw access or refresh token in
 * localStorage/sessionStorage under any circumstance.
 */
export function createOidcAuthProvider(): AuthProvider {
  return {
    async initialize(): Promise<AuthenticatedUser | null> {
      safeLogger.warn("oidcAuthProvider.initialize called but not implemented", {
        authority: appConfig.oidc.authority,
      });
      throw new Error(
        "oidcAuthProvider is not implemented yet. See features/auth/oidcAuthProvider.ts for the two supported integration patterns."
      );
    },
    async login() {
      throw new Error("oidcAuthProvider.login is not implemented yet.");
    },
    async logout() {
      throw new Error("oidcAuthProvider.logout is not implemented yet.");
    },
    async getAccessToken() {
      return null;
    },
  };
}
