import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { LoadingState } from "@/components/common/LoadingState";
import { Input } from "@/components/ui/Input";
import { useAdminUserList, useHasPermission } from "@/features/administration/useAdminUsers";
import type { DataTableColumn } from "@/types/ui";
import type { AdminUserListItemDto } from "@/types/api";

/** Mirrors iam.[User].UserStatus's CHECK constraint values exactly. */
const USER_STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning" | "danger"> = {
  Pending: "info",
  Active: "success",
  Inactive: "neutral",
  Locked: "danger",
  Deleted: "neutral",
};

export default function AdminUsersListPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const { loading: permissionLoading, allowed } = useHasPermission("user.read");
  const { data, isLoading, isError, error, refetch } = useAdminUserList(search || undefined);

  if (permissionLoading) return <LoadingState label="Checking permissions" />;
  if (!allowed) {
    return (
      <PermissionDenied message="Viewing user accounts requires the 'user.read' permission, which your current role does not grant." />
    );
  }

  const columns: DataTableColumn<AdminUserListItemDto>[] = [
    { id: "display_name", header: "Name", sortable: true, accessor: (row) => row.display_name },
    { id: "email", header: "Email", sortable: true, accessor: (row) => row.email },
    {
      id: "user_status",
      header: "Status",
      accessor: (row) => (
        <StatusBadge status={row.user_status} tone={USER_STATUS_TONE[row.user_status] ?? "neutral"} />
      ),
    },
    {
      id: "last_login_at_utc",
      header: "Last login",
      accessor: (row) => (row.last_login_at_utc ? new Date(row.last_login_at_utc).toLocaleString() : "Never"),
    },
  ];

  return (
    <>
      <PageHeader title="Users" description="Real accounts from iam.[User], searched/filtered server-side." />
      <div className="mb-3 max-w-sm">
        <Input
          type="search"
          placeholder="Search by name or email"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          aria-label="Search users"
        />
      </div>
      <DataTable
        columns={columns}
        rows={data?.items ?? []}
        getRowId={(row) => row.user_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No users found"
        emptyDescription="Try a different search term."
        onRowClick={(row) => navigate(`/admin/users/${row.user_id}`)}
      />
    </>
  );
}
