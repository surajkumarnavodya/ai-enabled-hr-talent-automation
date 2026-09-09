import type { RoleName } from "@/types/auth";
import type { Permission } from "@/hooks/usePermissions";

export interface NavItem {
  path: string;
  label: string;
  /** lucide-react icon name, resolved by Sidebar.tsx to keep this file dependency-free. */
  icon: string;
  requiredPermission?: Permission;
  requiredRoles?: RoleName[];
}

export interface NavSection {
  label: string;
  items: NavItem[];
}

/**
 * Single source of truth for primary navigation. Also referenced by tests to
 * assert every nav item resolves to a real route in routes.tsx. Permission/role
 * gating here is UX only — see hooks/usePermissions.ts header comment.
 */
export const navSections: NavSection[] = [
  {
    label: "Overview",
    items: [{ path: "/dashboard", label: "Dashboard", icon: "LayoutDashboard" }],
  },
  {
    label: "Recruitment",
    items: [
      { path: "/cv-bank", label: "CV Bank", icon: "FolderSearch" },
      { path: "/tans", label: "TANs", icon: "ClipboardList" },
      { path: "/interviews", label: "Interviews", icon: "CalendarClock" },
      { path: "/offers", label: "Offers", icon: "FileSignature" },
    ],
  },
  {
    label: "Onboarding",
    items: [
      { path: "/verification", label: "Verification", icon: "FileCheck2" },
      { path: "/discrepancies", label: "Discrepancies", icon: "AlertTriangle" },
      { path: "/employee-conversion", label: "Employee Conversion", icon: "UserCheck" },
    ],
  },
  {
    label: "Governance",
    items: [
      { path: "/approvals", label: "Approvals", icon: "CheckSquare" },
      { path: "/audit", label: "Audit", icon: "History" },
    ],
  },
  {
    label: "Administration",
    items: [
      {
        path: "/admin",
        label: "Administration",
        icon: "Settings",
        requiredPermission: "admin.access",
      },
    ],
  },
];
