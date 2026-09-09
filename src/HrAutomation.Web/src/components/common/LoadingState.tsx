export interface LoadingStateProps {
  label?: string;
  rows?: number;
  /** Render rows as a header bar + shorter body rows, closer to what a real
   * table/list looks like instead of uniform pulsing bars (see design audit
   * "table skeleton doesn't resemble the table it replaces"). */
  variant?: "default" | "table";
}

/** Skeleton loading placeholder. Always paired with `aria-busy`/`role="status"` for screen readers. */
export function LoadingState({ label = "Loading…", rows = 4, variant = "default" }: LoadingStateProps) {
  if (variant === "table") {
    return (
      <div role="status" aria-busy="true" aria-live="polite" className="overflow-hidden rounded-lg border border-subtle">
        <span className="sr-only">{label}</span>
        <div className="h-10 w-full animate-pulse bg-surface-sunken" aria-hidden="true" />
        <div className="divide-y divide-subtle">
          {Array.from({ length: rows }).map((_, i) => (
            <div key={i} className="flex items-center gap-4 px-4 py-3" aria-hidden="true">
              <div
                className="h-3.5 animate-pulse rounded bg-surface-sunken"
                style={{ width: `${65 - i * 6}%`, animationDelay: `${i * 60}ms` }}
              />
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div role="status" aria-busy="true" aria-live="polite" className="space-y-3">
      <span className="sr-only">{label}</span>
      {Array.from({ length: rows }).map((_, i) => (
        <div
          key={i}
          className="h-10 w-full animate-pulse rounded-md bg-surface-sunken"
          style={{ animationDelay: `${i * 60}ms` }}
          aria-hidden="true"
        />
      ))}
    </div>
  );
}
