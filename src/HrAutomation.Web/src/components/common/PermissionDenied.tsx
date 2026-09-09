import { Link } from "react-router-dom";
import { Lock } from "lucide-react";

export interface PermissionDeniedProps {
  message?: string;
}

export function PermissionDenied({
  message = "You don't have permission to view this page. If you believe this is incorrect, contact your HR administrator.",
}: PermissionDeniedProps) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 text-center">
      <Lock className="h-10 w-10 text-slate-400" aria-hidden="true" />
      <h1 className="text-lg font-semibold text-slate-900 dark:text-slate-50">Access denied</h1>
      <p className="max-w-sm text-sm text-slate-600 dark:text-slate-400">{message}</p>
      <Link
        to="/dashboard"
        className="inline-flex h-9 items-center justify-center rounded-md border border-slate-300 px-4 text-sm font-medium text-slate-900 hover:bg-slate-50 dark:border-slate-700 dark:text-slate-100 dark:hover:bg-slate-800"
      >
        Back to dashboard
      </Link>
    </div>
  );
}
