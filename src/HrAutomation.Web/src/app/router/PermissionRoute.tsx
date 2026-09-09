import { Navigate, Outlet } from "react-router-dom";
import { usePermissions, type Permission } from "@/hooks/usePermissions";
import type { RoleName } from "@/types/auth";

export interface PermissionRouteProps {
  permission?: Permission;
  roles?: RoleName[];
}

/**
 * UX-level authorization gate — hides routes the current role shouldn't see
 * in the UI. This is NOT the enforcement layer: HrAutomation.Api independently
 * authorizes every request. Never rely on this component alone for security;
 * see docs/05-security-governance/frontend-security.md.
 */
export function PermissionRoute({ permission, roles }: PermissionRouteProps) {
  const { hasPermission, hasAnyRole } = usePermissions();

  const allowed =
    (!permission || hasPermission(permission)) &&
    (!roles || roles.length === 0 || hasAnyRole(roles));

  if (!allowed) {
    return <Navigate to="/access-denied" replace />;
  }

  return <Outlet />;
}
