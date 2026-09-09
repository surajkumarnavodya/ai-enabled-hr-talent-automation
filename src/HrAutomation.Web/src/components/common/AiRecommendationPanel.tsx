import type { ReactNode } from "react";
import { Sparkles } from "lucide-react";
import { cn } from "@/lib/cn";

export interface AiRecommendationPanelProps {
  children: ReactNode;
  /** Defaults to the standard disclosure required everywhere AI output is shown. */
  label?: string;
  className?: string;
}

/**
 * Visual + semantic wrapper for ANY AI-generated content (match scores,
 * drafted text, suggested slots, etc.). Never remove or soften the label —
 * see CLAUDE.md "Keep AI output clearly labelled... do not present it as a
 * final decision" and docs/05-security-governance/frontend-security.md.
 */
export function AiRecommendationPanel({
  children,
  label = "AI recommendation — human approval required",
  className,
}: AiRecommendationPanelProps) {
  return (
    <section
      aria-label={label}
      className={cn(
        "rounded-lg border-2 border-dashed border-brand-300 bg-brand-50/50 p-4 dark:border-brand-800 dark:bg-brand-950/30",
        className
      )}
    >
      <div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-brand-700 dark:text-brand-400">
        <Sparkles className="h-4 w-4" aria-hidden="true" />
        <span>{label}</span>
      </div>
      {children}
    </section>
  );
}
