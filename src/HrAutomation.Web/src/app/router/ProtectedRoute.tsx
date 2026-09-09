import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { LoadingState } from "@/components/common/LoadingState";

/**
 * UI-level route guard only. The actual authorization boundary is
 * HrAutomation.Api — every request is re-validated server-side regardless of
 * what this component allows to render. See
 * docs/05-security-governance/frontend-security.md.
 */
export function ProtectedRoute() {
  const { status } = useAuth();
  const location = useLocation();

  if (status === "idle" || status === "authenticating") {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <LoadingState label="Checking session" rows={1} />
      </div>
    );
  }

  if (status !== "authenticated") {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <Outlet />;
}
