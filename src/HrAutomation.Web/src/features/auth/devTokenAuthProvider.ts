import axios from "axios";
import type { AuthProvider, AuthenticatedUser, MockLoginInput } from "@/types/auth";
import { appConfig } from "@/app/config/appConfig";
import { safeLogger } from "@/lib/safeLogger";
import { DEMO_TENANT_ID, DEMO_USER_ID_BY_ROLE } from "@/features/auth/demoUserDirectory";

/**
 * Development-only auth provider that calls HrAutomation.Api's real
 * `/api/v1/dev/token` endpoint (itself gated to ASPNETCORE_ENVIRONMENT=Development
 * and returning 404 otherwise) to obtain a real, signed JWT the backend accepts.
 * Unlike `mockAuthProvider`, every subsequent API call made with this provider's
 * token reaches the real database. Selected via VITE_AUTH_MODE=devToken.
 *
 * The token is kept in module memory only, never localStorage/sessionStorage —
 * same rule as mockAuthProvider. A page reload loses the session by design.
 *
 * This is not a production auth pattern — see DECISIONS_REQUIRED.md DEC-002 for
 * the still-open choice between real OIDC and a BFF cookie session.
 */
let currentUser: AuthenticatedUser | null = null;
let currentAccessToken: string | null = null;

// Deliberately not the shared `apiClient` instance - that instance's request
// interceptor calls this provider's own getAccessToken(), which would be a
// circular dependency at call time for the one request (login) that doesn't
// have a token yet. A dev-token request also needs none of apiClient's
// idempotency-key/auth-attach behavior.
const devTokenHttp = axios.create({ baseURL: appConfig.apiBaseUrl, timeout: appConfig.apiTimeoutMs });

interface DevTokenResponse {
  access_token: string;
  expires_at_utc: string;
  tenant_id: string;
  user_id: string;
}

interface UserProfileResponse {
  user_id: string;
  tenant_id: string;
  display_name: string;
  role: string;
  department_scope: string | null;
}

export function createDevTokenAuthProvider(): AuthProvider {
  return {
    async initialize() {
      safeLogger.debug("devTokenAuthProvider.initialize", { hasSession: Boolean(currentUser) });
      return currentUser;
    },

    async login(input?: MockLoginInput) {
      const role = input?.role ?? "RECRUITER";
      const userId = DEMO_USER_ID_BY_ROLE[role];

      const tokenResponse = await devTokenHttp.post<DevTokenResponse>("/v1/dev/token", {
        role,
        tenant_id: DEMO_TENANT_ID,
        user_id: userId, // omitted (undefined) -> backend mints a fresh id for roles with no seeded demo user
      });
      currentAccessToken = tokenResponse.data.access_token;

      const profileResponse = await devTokenHttp.get<UserProfileResponse>("/v1/users/me", {
        headers: { Authorization: `Bearer ${currentAccessToken}` },
      });
      const profile = profileResponse.data;

      currentUser = {
        userId: profile.user_id,
        tenantId: profile.tenant_id,
        displayName: profile.display_name,
        role: role,
        departmentScope: profile.department_scope ?? undefined,
      };
      safeLogger.info("devTokenAuthProvider.login", { role });
      return currentUser;
    },

    async logout() {
      currentUser = null;
      currentAccessToken = null;
      safeLogger.info("devTokenAuthProvider.logout");
    },

    async getAccessToken() {
      return currentAccessToken;
    },
  };
}
