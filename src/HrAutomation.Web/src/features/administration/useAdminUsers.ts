import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import { useAuth } from "@/hooks/useAuth";
import type {
  AdminUserDetailDto,
  AdminUserListItemDto,
  CursorPage,
  EffectivePermissionsDto,
} from "@/types/api";

/**
 * Real, database-backed effective permissions for the signed-in user
 * (iam.UserRole -> iam.Role -> iam.RolePermission -> iam.Permission). This is the
 * server-authoritative gate for the Administration module's fine-grained screens
 * (e.g. "user.read") - distinct from the coarser hooks/usePermissions.ts UX model
 * used elsewhere in the app. Still UX-only: every admin endpoint independently
 * re-checks server-side regardless of what this hook returns.
 */
export function useEffectivePermissions() {
  const { status } = useAuth();
  return useQuery({
    queryKey: [QUERY_KEYS.admin, "effectivePermissions"],
    queryFn: () => http.get<EffectivePermissionsDto>("/v1/users/me/permissions"),
    enabled: status === "authenticated",
    staleTime: 60_000,
  });
}

export function useHasPermission(permissionKey: string): { loading: boolean; allowed: boolean } {
  const { data, isLoading } = useEffectivePermissions();
  return { loading: isLoading, allowed: Boolean(data?.permissions.includes(permissionKey)) };
}

export function useAdminUserList(search: string | undefined, cursor?: string) {
  return useQuery({
    queryKey: [QUERY_KEYS.admin, "users", "list", search ?? null, cursor ?? null],
    queryFn: () =>
      http.get<CursorPage<AdminUserListItemDto>>("/v1/admin/users", {
        params: { search: search || undefined, cursor, limit: 20 },
      }),
  });
}

export function useAdminUserDetail(userId: string | undefined) {
  return useQuery({
    queryKey: [QUERY_KEYS.admin, "users", userId],
    queryFn: () => http.get<AdminUserDetailDto>(`/v1/admin/users/${userId}`),
    enabled: Boolean(userId),
  });
}
