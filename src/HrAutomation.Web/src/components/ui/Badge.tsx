import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";
import type { StatusTone } from "@/types/ui";

/* Every tone pairs the semantic status color with its own tint token (see
   globals.css @theme) — never an unrelated Tailwind hue (e.g. the old
   `emerald-50`/`amber-50` palette, which wasn't actually tied to
   `--color-status-success`/`--color-status-warning`). Light/dark handled via
   the `-tint-dark` variant token, not a hardcoded `dark:bg-emerald-950`. */
const TONE_CLASSES: Record<StatusTone, string> = {
  success:
    "bg-status-success-tint text-status-success ring-1 ring-inset ring-status-success/25 dark:bg-status-success-tint-dark",
  warning:
    "bg-status-warning-tint text-status-warning ring-1 ring-inset ring-status-warning/25 dark:bg-status-warning-tint-dark",
  danger:
    "bg-status-danger-tint text-status-danger ring-1 ring-inset ring-status-danger/25 dark:bg-status-danger-tint-dark",
  info: "bg-status-info-tint text-status-info ring-1 ring-inset ring-status-info/25 dark:bg-status-info-tint-dark",
  pending:
    "bg-status-pending-tint text-status-pending ring-1 ring-inset ring-status-pending/25 dark:bg-status-pending-tint-dark",
  neutral:
    "bg-status-neutral-tint text-status-neutral ring-1 ring-inset ring-status-neutral/20 dark:bg-status-neutral-tint-dark",
};

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: StatusTone;
}

export function Badge({ tone = "neutral", className, children, ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium",
        TONE_CLASSES[tone],
        className
      )}
      {...props}
    >
      {children}
    </span>
  );
}
