import { History } from "lucide-react";
import { formatDateTime } from "@/lib/dateUtils";
import { EmptyState } from "@/components/common/EmptyState";
import type { AuditLogEntry } from "@/types/workflow";

export interface AuditTimelineProps {
  entries: AuditLogEntry[];
}

/**
 * Renders only what the API returned for the current user's permissions —
 * never assume additional audit detail exists beyond the response payload.
 * See docs/05-security-governance/frontend-security.md.
 */
export function AuditTimeline({ entries }: AuditTimelineProps) {
  if (entries.length === 0) {
    return <EmptyState title="No audit activity yet" icon={<History className="h-8 w-8" />} />;
  }

  return (
    <ol className="relative space-y-4 border-l border-slate-200 pl-4 dark:border-slate-800">
      {entries.map((entry) => (
        <li key={entry.id} className="relative">
          <span
            className="absolute -left-[1.3rem] top-1 h-2.5 w-2.5 rounded-full bg-brand-500"
            aria-hidden="true"
          />
          <p className="text-sm font-medium text-slate-900 dark:text-slate-100">{entry.action}</p>
          <p className="text-xs text-slate-500 dark:text-slate-400">
            {formatDateTime(entry.occurredAt)} · {entry.actorLabel} ({entry.actorType})
          </p>
        </li>
      ))}
    </ol>
  );
}
