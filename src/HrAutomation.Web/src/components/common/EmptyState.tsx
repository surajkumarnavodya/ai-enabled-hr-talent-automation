import type { ReactNode } from "react";
import { Inbox, Lock } from "lucide-react";
import { cn } from "@/lib/cn";

export type EmptyStateVariant = "empty" | "restricted";

export interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: ReactNode;
  action?: ReactNode;
  /** "restricted" reads as a permission boundary, not an empty result set —
   * see design audit "can't distinguish 'nothing here' from 'not allowed'". */
  variant?: EmptyStateVariant;
}

const VARIANT_STYLES: Record<EmptyStateVariant, { border: string; iconWrap: string }> = {
  empty: { border: "border-dashed border-strong", iconWrap: "bg-surface-sunken text-tertiary" },
  restricted: {
    border: "border-solid border-subtle",
    iconWrap: "bg-status-neutral-tint text-status-neutral dark:bg-status-neutral-tint-dark",
  },
};

export function EmptyState({ title, description, icon, action, variant = "empty" }: EmptyStateProps) {
  const styles = VARIANT_STYLES[variant];
  const defaultIcon = variant === "restricted" ? <Lock className="h-6 w-6" /> : <Inbox className="h-6 w-6" />;

  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-lg border p-10 text-center",
        styles.border
      )}
    >
      <div className={cn("mb-3 rounded-full p-2.5", styles.iconWrap)} aria-hidden="true">
        {icon ?? defaultIcon}
      </div>
      <p className="text-sm font-medium text-primary">{title}</p>
      {description && <p className="mt-1 max-w-sm text-sm text-secondary">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
