import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { LogOut, ChevronDown } from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { initials } from "@/lib/formatters";
import { cn } from "@/lib/cn";

/** Compact identity + sign-out surface. Replaces a bare "name · role" string
 * and unstyled sign-out link with a real menu — see design audit "no
 * profile/account menu". */
export function ProfileMenu() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onPointerDown(e: PointerEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, []);

  if (!user) return null;

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="menu"
        aria-expanded={open}
        className="flex items-center gap-2 rounded-md py-1 pl-1 pr-2 text-sm transition-colors duration-150 hover:bg-surface-sunken"
      >
        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-600 text-xs font-semibold text-white">
          {initials(user.displayName) || "?"}
        </span>
        <span className="hidden flex-col items-start leading-tight sm:flex">
          <span className="font-medium text-primary">{user.displayName}</span>
          <span className="text-caption text-tertiary">{user.role}</span>
        </span>
        <ChevronDown
          className={cn("h-3.5 w-3.5 text-tertiary transition-transform duration-150", open && "rotate-180")}
          aria-hidden="true"
        />
      </button>

      {open && (
        <div
          role="menu"
          className="animate-scale-in absolute right-0 top-full z-40 mt-1.5 w-48 origin-top-right rounded-lg border border-subtle bg-surface-raised p-1 shadow-lg"
        >
          <div className="border-b border-subtle px-2.5 py-2 sm:hidden">
            <p className="text-sm font-medium text-primary">{user.displayName}</p>
            <p className="text-caption text-tertiary">{user.role}</p>
          </div>
          <Link
            to="/logout"
            role="menuitem"
            onClick={() => setOpen(false)}
            className="flex items-center gap-2 rounded-md px-2.5 py-2 text-sm text-secondary transition-colors duration-150 hover:bg-surface-sunken hover:text-primary"
          >
            <LogOut className="h-4 w-4" aria-hidden="true" />
            Sign out
          </Link>
        </div>
      )}
    </div>
  );
}
