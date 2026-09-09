import { useId, type ReactNode, cloneElement, isValidElement } from "react";
import { cn } from "@/lib/cn";

export interface FormFieldProps {
  label: string;
  required?: boolean;
  error?: string;
  hint?: string;
  children: ReactNode;
}

/**
 * Wraps a single form control with an associated <label>, required indicator,
 * hint text, and an accessible error message (aria-describedby + aria-invalid
 * wired onto the child control automatically).
 */
export function FormField({ label, required, error, hint, children }: FormFieldProps) {
  const fieldId = useId();
  const errorId = `${fieldId}-error`;
  const hintId = `${fieldId}-hint`;

  const describedBy = [error && errorId, hint && hintId].filter(Boolean).join(" ") || undefined;

  const control = isValidElement(children)
    ? cloneElement(children as React.ReactElement<Record<string, unknown>>, {
        id: fieldId,
        "aria-invalid": Boolean(error) || undefined,
        "aria-describedby": describedBy,
        "aria-required": required || undefined,
      })
    : children;

  return (
    <div className="mb-4">
      <label htmlFor={fieldId} className="mb-1 block text-sm font-medium text-secondary">
        {label}
        {required && (
          <span className="ml-0.5 text-status-danger" aria-hidden="true">
            *
          </span>
        )}
      </label>
      {control}
      {hint && !error && (
        <p id={hintId} className="mt-1 text-xs text-tertiary">
          {hint}
        </p>
      )}
      {error && (
        <p id={errorId} className={cn("mt-1 text-xs text-status-danger")} role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
