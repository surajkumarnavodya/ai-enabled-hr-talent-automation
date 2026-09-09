import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";
import type { StatusTone } from "@/types/ui";

const TONE_CLASSES: Record<StatusTone, string> = {
  success:
    "bg-emerald-50 text-status-success ring-1 ring-inset ring-emerald-200 dark:bg-emerald-950 dark:ring-emerald-800",
  warning:
    "bg-amber-50 text-status-warning ring-1 ring-inset ring-amber-200 dark:bg-amber-950 dark:ring-amber-800",
  danger:
    "bg-red-50 text-status-danger ring-1 ring-inset ring-red-200 dark:bg-red-950 dark:ring-red-800",
  info: "bg-blue-50 text-status-info ring-1 ring-inset ring-blue-200 dark:bg-blue-950 dark:ring-blue-800",
  neutral:
    "bg-slate-100 text-status-neutral ring-1 ring-inset ring-slate-200 dark:bg-slate-800 dark:ring-slate-700",
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
