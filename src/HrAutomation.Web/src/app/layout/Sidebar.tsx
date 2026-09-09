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
  onNavigate?: () => void;
}

export function Sidebar({ open, onNavigate }: SidebarProps) {
  const { hasPermission } = usePermissions();

  return (
    <aside
      className={cn(
        "w-64 shrink-0 border-r border-slate-200 bg-white transition-transform dark:border-slate-800 dark:bg-slate-950",
        "fixed inset-y-0 left-0 z-30 lg:static lg:translate-x-0",
        open ? "translate-x-0" : "-translate-x-full"
      )}
      aria-label="Primary navigation"
    >
      <nav className="h-full overflow-y-auto p-4">
        {navSections.map((section) => {
          const visibleItems = section.items.filter(
            (item) => !item.requiredPermission || hasPermission(item.requiredPermission)
          );
          if (visibleItems.length === 0) return null;

          return (
            <div key={section.label} className="mb-6">
              <h2 className="mb-2 px-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
                {section.label}
              </h2>
              <ul className="space-y-1">
                {visibleItems.map((item) => {
                  const Icon = ICONS[item.icon] ?? LayoutDashboard;
                  return (
                    <li key={item.path}>
                      <NavLink
                        to={item.path}
                        onClick={onNavigate}
                        className={({ isActive }) =>
                          cn(
                            "flex items-center gap-2.5 rounded-md px-2.5 py-2 text-sm font-medium",
                            isActive
                              ? "bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-400"
                              : "text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
                          )
                        }
                      >
                        <Icon className="h-4 w-4" aria-hidden="true" />
                        {item.label}
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
