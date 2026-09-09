import type { AuthProvider, AuthenticatedUser, MockLoginInput } from "@/types/auth";
import { safeLogger } from "@/lib/safeLogger";

/**
 * Local-development-only auth provider. No network calls, no real token —
 * issues a short synthetic identity held in memory only (never persisted to
 * localStorage/sessionStorage). Selected via VITE_AUTH_MODE=mock (the
 * scaffold default). Swap to `oidcAuthProvider` for any non-local environment.
 */
const MOCK_SESSION_STORAGE_KEY_WARNING =
  "mockAuthProvider intentionally keeps identity in module memory only, not storage.";

let currentUser: AuthenticatedUser | null = null;

export function createMockAuthProvider(): AuthProvider {
  return {
    async initialize() {
      safeLogger.debug("mockAuthProvider.initialize", { hasSession: Boolean(currentUser) });
      return currentUser;
    },

    async login(input?: MockLoginInput) {
      const role = input?.role ?? "RECRUITER";
      currentUser = {
        userId: "mock-user-0001",
        tenantId: "mock-tenant-demo",
        displayName: input?.displayName ?? `Demo ${role}`,
        role,
      };
      safeLogger.info("mockAuthProvider.login", { role });
      void MOCK_SESSION_STORAGE_KEY_WARNING;
      return currentUser;
    },

    async logout() {
      currentUser = null;
      safeLogger.info("mockAuthProvider.logout");
    },

    async getAccessToken() {
      // A fixed, non-secret placeholder string — MSW handlers accept any
      // Authorization header in mock mode. Never a real signing key or JWT.
      return currentUser ? "mock-dev-session-token" : null;
    },
  };
}
