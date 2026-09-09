import { Link } from "react-router-dom";
import { Lock } from "lucide-react";

export interface PermissionDeniedProps {
  message?: string;
}

export function PermissionDenied({
  message = "You don't have permission to view this page. If you believe this is incorrect, contact your HR administrator.",
}: PermissionDeniedProps) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 py-12 text-center">
      <div className="rounded-full bg-status-danger-tint p-3 dark:bg-status-danger-tint-dark">
        <Lock className="h-6 w-6 text-status-danger" aria-hidden="true" />
      </div>
      <h1 className="text-page-title text-primary">Access denied</h1>
      <p className="max-w-sm text-sm text-secondary">{message}</p>
      <Link
        to="/dashboard"
        className="inline-flex h-9 items-center justify-center rounded-md border border-strong px-4 text-sm font-medium text-primary transition-colors duration-150 hover:bg-surface-sunken"
      >
        Back to dashboard
      </Link>
    </div>
  );
}
