import type { ReactNode } from "react";

export interface FormSectionProps {
  title: string;
  description?: string;
  children: ReactNode;
}

/**
 * Groups related fields under a heading so longer forms read as scannable
 * chunks instead of one flat vertical list (see design audit "forms have no
 * visual sectioning"). Purely presentational — validation/submission stay in
 * the parent form.
 */
export function FormSection({ title, description, children }: FormSectionProps) {
  return (
    <fieldset className="mt-6 border-t border-subtle pt-5 first:mt-0 first:border-t-0 first:pt-0">
      <legend className="mb-0.5 text-section-title text-primary">{title}</legend>
      {description && <p className="mb-4 text-sm text-secondary">{description}</p>}
      {!description && <div className="mb-4" />}
      <div className="space-y-4">{children}</div>
    </fieldset>
  );
}
