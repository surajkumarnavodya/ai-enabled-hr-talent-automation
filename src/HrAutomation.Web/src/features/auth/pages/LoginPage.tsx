import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { ShieldCheck } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { appConfig } from "@/app/config/appConfig";
import { ALL_ROLES } from "@/lib/constants";
import type { RoleName } from "@/types/auth";
import { Button } from "@/components/ui/Button";

/**
 * Mock-mode login lets a developer pick any role to exercise permission-gated
 * UI locally. In VITE_AUTH_MODE=oidc this page instead redirects to the real
 * identity provider (or, for a BFF setup, to the BFF's /login endpoint) — see
 * features/auth/oidcAuthProvider.ts.
 */
export default function LoginPage() {
  const { login, status, error } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [selectedRole, setSelectedRole] = useState<RoleName>("RECRUITER");

  const redirectTo = (location.state as { from?: string } | null)?.from ?? "/dashboard";

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    await login({ role: selectedRole });
    navigate(redirectTo, { replace: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 px-4 dark:bg-slate-950">
      <div className="w-full max-w-sm rounded-lg border border-slate-200 bg-white p-8 shadow-sm dark:border-slate-800 dark:bg-slate-900">
        <div className="mb-6 flex items-center gap-2">
          <ShieldCheck className="h-6 w-6 text-brand-600" aria-hidden="true" />
          <h1 className="text-lg font-semibold text-slate-900 dark:text-slate-50">
            HR Automation Platform
          </h1>
        </div>

        {appConfig.authMode === "mock" || appConfig.authMode === "devToken" ? (
          <form onSubmit={handleSubmit} noValidate>
            <p className="mb-4 text-sm text-slate-600 dark:text-slate-400">
              {appConfig.authMode === "devToken"
                ? "Development sign-in against the real API. Issues a real, short-lived token from a Development-only backend endpoint for a seeded demo identity — not a production auth flow."
                : "Local development sign-in. Select a role to preview its permissions. This mode never calls a real identity provider or a real API."}
            </p>
            <label
              htmlFor="role-select"
              className="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              Role
            </label>
            <select
              id="role-select"
              className="mb-4 w-full rounded-md border border-slate-300 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-800"
              value={selectedRole}
              onChange={(e) => setSelectedRole(e.target.value as RoleName)}
            >
              {ALL_ROLES.map((role) => (
                <option key={role} value={role}>
                  {role}
                </option>
              ))}
            </select>

            {error && (
              <p role="alert" className="mb-4 text-sm text-status-danger">
                {error}
              </p>
            )}

            <Button type="submit" className="w-full" disabled={status === "authenticating"}>
              {status === "authenticating" ? "Signing in…" : "Sign in"}
            </Button>
          </form>
        ) : (
          <p className="text-sm text-slate-600 dark:text-slate-400">
            Redirecting to your organization's sign-in page…
          </p>
        )}
      </div>
    </div>
  );
}
