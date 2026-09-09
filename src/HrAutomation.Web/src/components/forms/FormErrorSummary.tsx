import { useEffect, useRef } from "react";
import { AlertCircle } from "lucide-react";

export interface FormErrorSummaryProps {
  errors: Record<string, { message?: string } | undefined>;
}

/**
 * WCAG-recommended error summary: rendered at the top of a form, focused on
 * submission failure, and links down to each invalid field. Required for the
 * "accessible forms... error summary" UX rule.
 */
export function FormErrorSummary({ errors }: FormErrorSummaryProps) {
  const ref = useRef<HTMLDivElement>(null);
  const entries = Object.entries(errors).filter(([, v]) => v?.message);

  useEffect(() => {
    if (entries.length > 0) ref.current?.focus();
  }, [entries.length]);

  if (entries.length === 0) return null;

  return (
    <div
      ref={ref}
      tabIndex={-1}
      role="alert"
      className="mb-4 rounded-md border border-red-200 bg-red-50 p-3 dark:border-red-900 dark:bg-red-950"
    >
      <div className="flex items-center gap-2 text-sm font-medium text-status-danger">
        <AlertCircle className="h-4 w-4" aria-hidden="true" />
        Please fix the following {entries.length === 1 ? "error" : "errors"}:
      </div>
      <ul className="mt-2 list-inside list-disc text-sm text-status-danger">
        {entries.map(([field, err]) => (
          <li key={field}>
            <a href={`#${field}`} className="underline underline-offset-2">
              {err?.message}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
