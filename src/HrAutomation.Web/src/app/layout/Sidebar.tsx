import { NavLink } from "react-router-dom";
import {
  LayoutDashboard,
  FolderSearch,
  ClipboardList,
  CalendarClock,
  FileSignature,
  FileCheck2,
  AlertTriangle,
  UserCheck,
  CheckSquare,
  History,
  Settings,
  type LucideIcon,
} from "lucide-react";
import { navSections } from "@/app/router/routeConfig";
import { usePermissions } from "@/hooks/usePermissions";
import { cn } from "@/lib/cn";

const ICONS: Record<string, LucideIcon> = {
  LayoutDashboard,
  FolderSearch,
  ClipboardList,
  CalendarClock,
  FileSignature,
  FileCheck2,
  AlertTriangle,
  UserCheck,
  CheckSquare,
  History,
  Settings,
};

export interface SidebarProps {
  open: boolean;
  collapsed: boolean;
  onNavigate?: () => void;
}

export function Sidebar({ open, collapsed, onNavigate }: SidebarProps) {
  const { hasPermission } = usePermissions();

  return (
    <aside
      className={cn(
        "shrink-0 border-r border-subtle bg-surface transition-[width,transform] duration-200 ease-out",
        "fixed inset-y-0 left-0 z-30 lg:static lg:translate-x-0",
        collapsed ? "lg:w-[68px]" : "lg:w-64",
        "w-64",
        open ? "translate-x-0" : "-translate-x-full"
      )}
      aria-label="Primary navigation"
    >
      <nav className="h-full overflow-y-auto overflow-x-hidden p-3">
        {navSections.map((section) => {
          const visibleItems = section.items.filter(
            (item) => !item.requiredPermission || hasPermission(item.requiredPermission)
          );
          if (visibleItems.length === 0) return null;

          return (
            <div key={section.label} className="mb-5">
              {!collapsed && (
                <h2 className="mb-1.5 px-2.5 text-caption font-semibold uppercase tracking-wide text-tertiary">
                  {section.label}
                </h2>
              )}
              <ul className="space-y-0.5">
                {visibleItems.map((item) => {
                  const Icon = ICONS[item.icon] ?? LayoutDashboard;
                  return (
                    <li key={item.path}>
                      <NavLink
                        to={item.path}
                        onClick={onNavigate}
                        title={collapsed ? item.label : undefined}
                        className={({ isActive }) =>
                          cn(
                            "group relative flex items-center gap-2.5 rounded-md px-2.5 py-2 text-sm font-medium transition-colors duration-150",
                            collapsed && "lg:justify-center",
                            isActive
                              ? "bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-400"
                              : "text-secondary hover:bg-surface-sunken hover:text-primary"
                          )
                        }
                      >
                        {({ isActive }) => (
                          <>
                            {isActive && (
                              <span className="absolute left-0 top-1/2 h-4 w-0.5 -translate-y-1/2 rounded-full bg-brand-600" />
                            )}
                            <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
                            <span className={cn(collapsed && "lg:hidden")}>{item.label}</span>
                          </>
                        )}
                      </NavLink>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}
      </nav>
    </aside>
  );
}
