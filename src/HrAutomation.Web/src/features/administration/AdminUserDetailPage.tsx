import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { StatusBadge } from "@/components/common/StatusBadge";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { useAdminUserDetail, useHasPermission } from "@/features/administration/useAdminUsers";

const USER_STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning" | "danger"> = {
  Pending: "info",
  Active: "success",
  Inactive: "neutral",
  Locked: "danger",
  Deleted: "neutral",
};

export default function AdminUserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const { loading: permissionLoading, allowed } = useHasPermission("user.read");
  const { data: user, isLoading, isError, refetch } = useAdminUserDetail(userId);

  if (permissionLoading) return <LoadingState label="Checking permissions" />;
  if (!allowed) {
    return (
      <PermissionDenied message="Viewing user accounts requires the 'user.read' permission, which your current role does not grant." />
    );
  }
  if (isLoading) return <LoadingState label="Loading user" />;
  if (isError || !user) return <ErrorState onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title={user.display_name}
        breadcrumbs={[{ label: "Users", to: "/admin/users" }, { label: user.display_name }]}
        actions={<StatusBadge status={user.user_status} tone={USER_STATUS_TONE[user.user_status] ?? "neutral"} />}
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Profile</h2>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Email</dt>
                <dd className="text-slate-900 dark:text-slate-100">{user.email}</dd>
              </div>
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Job title</dt>
                <dd className="text-slate-900 dark:text-slate-100">{user.job_title ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Department</dt>
                <dd className="text-slate-900 dark:text-slate-100">{user.department_name ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Location</dt>
                <dd className="text-slate-900 dark:text-slate-100">{user.location_name ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Last login</dt>
                <dd className="text-slate-900 dark:text-slate-100">
                  {user.last_login_at_utc ? new Date(user.last_login_at_utc).toLocaleString() : "Never"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500 dark:text-slate-400">Created</dt>
                <dd className="text-slate-900 dark:text-slate-100">
                  {new Date(user.created_at_utc).toLocaleString()}
                </dd>
              </div>
            </dl>

            {user.allowed_actions.length === 0 && (
              <p className="mt-4 text-xs text-slate-500 dark:text-slate-400">
                Your role does not currently grant any management action on this user (update, deactivate,
                or role assignment) — this is computed server-side from your effective permissions, not a UI
                restriction.
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Assigned roles</h2>
          </CardHeader>
          <CardContent>
            {user.roles.length === 0 ? (
              <EmptyState title="No roles assigned" description="This user has no active role assignment." />
            ) : (
              <ul className="flex flex-col gap-2">
                {user.roles.map((role) => (
                  <li key={role.user_role_id} className="flex items-center justify-between text-sm">
                    <Badge tone="neutral">{role.role_name}</Badge>
                    <span className="text-xs text-slate-500 dark:text-slate-400">
                      since {new Date(role.assigned_at_utc).toLocaleDateString()}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </>
  );
}
