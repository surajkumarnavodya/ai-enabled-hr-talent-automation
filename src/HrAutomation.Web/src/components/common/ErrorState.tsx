import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/Button";

export interface ErrorStateProps {
  /** User-safe message only — never a raw stack trace or backend exception detail. */
  message?: string;
  onRetry?: () => void;
}

export function ErrorState({
  message = "Something went wrong loading this data. Please try again.",
  onRetry,
}: ErrorStateProps) {
  return (
    <div
      role="alert"
      className="flex flex-col items-center justify-center rounded-lg border border-red-200 bg-red-50 p-8 text-center dark:border-red-900 dark:bg-red-950"
    >
      <AlertTriangle className="mb-3 h-8 w-8 text-status-danger" aria-hidden="true" />
      <p className="text-sm font-medium text-slate-900 dark:text-slate-100">{message}</p>
      {onRetry && (
        <Button variant="outline" size="sm" className="mt-4" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}
