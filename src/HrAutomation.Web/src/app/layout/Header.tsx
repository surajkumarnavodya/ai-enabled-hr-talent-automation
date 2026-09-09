import { Link } from "react-router-dom";
import { Menu, PanelLeftClose, PanelLeftOpen } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { ThemeToggle } from "@/app/layout/ThemeToggle";
import { ProfileMenu } from "@/app/layout/ProfileMenu";

export interface HeaderProps {
  onToggleSidebar: () => void;
  sidebarCollapsed: boolean;
  onToggleCollapsed: () => void;
}

export function Header({ onToggleSidebar, sidebarCollapsed, onToggleCollapsed }: HeaderProps) {
  const { user } = useAuth();

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-subtle bg-surface/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-surface/80">
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          onClick={onToggleSidebar}
          className="rounded-md p-1.5 text-secondary transition-colors duration-150 hover:bg-surface-sunken lg:hidden"
          aria-label="Toggle navigation menu"
        >
          <Menu className="h-5 w-5" aria-hidden="true" />
        </button>
        <button
          type="button"
          onClick={onToggleCollapsed}
          className="hidden rounded-md p-1.5 text-secondary transition-colors duration-150 hover:bg-surface-sunken lg:inline-flex"
          aria-label={sidebarCollapsed ? "Expand navigation" : "Collapse navigation"}
          title={sidebarCollapsed ? "Expand navigation" : "Collapse navigation"}
        >
          {sidebarCollapsed ? (
            <PanelLeftOpen className="h-4 w-4" aria-hidden="true" />
          ) : (
            <PanelLeftClose className="h-4 w-4" aria-hidden="true" />
          )}
        </button>
        <Link to="/dashboard" className="ml-1 flex items-center gap-2 text-sm font-semibold text-primary">
          <span className="flex h-6 w-6 items-center justify-center rounded-md bg-brand-600 text-xs font-bold text-white">
            HR
          </span>
          <span className="hidden sm:inline">HR Automation Platform</span>
        </Link>
      </div>

      {user && (
        <div className="flex items-center gap-3">
          <ThemeToggle />
          <ProfileMenu />
        </div>
      )}
    </header>
  );
}
