import { Link, Outlet, useLocation } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { cn } from "@/lib/cn";

const TABS = [
  { to: "/admin/users", label: "Users" },
  { to: "/admin/configuration", label: "Workflow configuration" },
  { to: "/admin/roles", label: "Roles & permissions" },
  { to: "/admin/feature-flags", label: "Feature flags" },
  { to: "/admin/integrations", label: "Integration health" },
];

export default function AdminPage() {
  const location = useLocation();
  const isIndex = location.pathname === "/admin";

  return (
    <>
      <PageHeader title="Administration" description="Restricted to authorized administrators." />
      <div className="mb-6 flex gap-1 border-b border-subtle">
        {TABS.map((tab) => (
          <Link
            key={tab.to}
            to={tab.to}
            className={cn(
              "border-b-2 px-3 py-2 text-sm font-medium",
              location.pathname === tab.to
                ? "border-brand-600 text-brand-700 dark:text-brand-400"
                : "border-transparent text-tertiary hover:text-primary"
            )}
          >
            {tab.label}
          </Link>
        ))}
      </div>
      {isIndex ? (
        <p className="text-sm text-secondary">Select a configuration area above.</p>
      ) : (
        <Outlet />
      )}
    </>
  );
}
