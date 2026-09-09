import type { AdminUserDetailDto, AdminUserListItemDto, EffectivePermissionsDto } from "@/types/api";

export const mockEffectivePermissions: EffectivePermissionsDto = {
  permissions: ["user.read", "role.read", "permission.read", "tan.read"],
};

export const mockAdminUsers: AdminUserListItemDto[] = [
  {
    user_id: "admin-user-0001",
    email: "demo.recruiter@example.test",
    display_name: "Demo Recruiter",
    user_status: "Active",
    is_system_service_account: false,
    last_login_at_utc: "2026-09-08T10:00:00Z",
    created_at_utc: "2026-01-05T09:00:00Z",
    row_version: "AAAAAAAAAAA=",
  },
  {
    user_id: "admin-user-0002",
    email: "demo.hr.admin@example.test",
    display_name: "Demo HR Administrator",
    user_status: "Active",
    is_system_service_account: false,
    last_login_at_utc: null,
    created_at_utc: "2026-01-05T09:00:00Z",
    row_version: "AAAAAAAAAAA=",
  },
];

export const mockAdminUserDetails: Record<string, AdminUserDetailDto> = {
  "admin-user-0001": {
    user_id: "admin-user-0001",
    tenant_id: "demo-tenant",
    email: "demo.recruiter@example.test",
    display_name: "Demo Recruiter",
    user_status: "Active",
    is_system_service_account: false,
    first_name: "Demo",
    last_name: "Recruiter",
    phone_number: null,
    job_title: "Recruiter",
    department_name: "HR Department",
    location_name: "Mumbai",
    last_login_at_utc: "2026-09-08T10:00:00Z",
    created_at_utc: "2026-01-05T09:00:00Z",
    roles: [
      {
        user_role_id: "user-role-0001",
        role_id: "role-recruiter",
        role_name: "RECRUITER",
        assigned_at_utc: "2026-01-05T09:00:00Z",
      },
    ],
    row_version: "AAAAAAAAAAA=",
    allowed_actions: [],
  },
};
