import { Link } from "react-router-dom";
import { Menu, LogOut, UserCircle } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";

export interface HeaderProps {
  onToggleSidebar: () => void;
}

export function Header({ onToggleSidebar }: HeaderProps) {
  const { user } = useAuth();

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-slate-200 bg-white px-4 dark:border-slate-800 dark:bg-slate-950">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={onToggleSidebar}
          className="rounded-md p-1.5 text-slate-500 hover:bg-slate-100 lg:hidden dark:hover:bg-slate-800"
          aria-label="Toggle navigation menu"
        >
          <Menu className="h-5 w-5" aria-hidden="true" />
        </button>
        <Link to="/dashboard" className="text-sm font-semibold text-slate-900 dark:text-slate-50">
          HR Automation Platform
        </Link>
      </div>

      {user && (
        <div className="flex items-center gap-3 text-sm">
          <span className="hidden items-center gap-1.5 text-slate-600 sm:flex dark:text-slate-300">
            <UserCircle className="h-4 w-4" aria-hidden="true" />
            {user.displayName} <span className="text-slate-400">· {user.role}</span>
          </span>
          <Link
            to="/logout"
            className="flex items-center gap-1.5 rounded-md px-2 py-1.5 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800"
          >
            <LogOut className="h-4 w-4" aria-hidden="true" />
            <span className="hidden sm:inline">Sign out</span>
          </Link>
        </div>
      )}
    </header>
  );
}
