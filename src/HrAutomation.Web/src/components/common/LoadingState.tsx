export interface LoadingStateProps {
  label?: string;
  rows?: number;
}

/** Skeleton loading placeholder. Always paired with `aria-busy`/`role="status"` for screen readers. */
export function LoadingState({ label = "Loading…", rows = 4 }: LoadingStateProps) {
  return (
    <div role="status" aria-busy="true" aria-live="polite" className="space-y-3">
      <span className="sr-only">{label}</span>
      {Array.from({ length: rows }).map((_, i) => (
        <div
          key={i}
          className="h-10 w-full animate-pulse rounded-md bg-slate-100 dark:bg-slate-800"
          aria-hidden="true"
        />
      ))}
    </div>
  );
}
