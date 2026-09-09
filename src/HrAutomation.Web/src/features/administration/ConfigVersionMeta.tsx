import { ShieldCheck } from "lucide-react";
import { formatDate } from "@/lib/dateUtils";

export interface ConfigVersionMetaProps {
  version: string;
  effectiveDate: string;
  approvedBy: string;
}

/**
 * Every configuration surface in Administration must show version, effective
 * date, approver, and an audit-requirement notice — see CLAUDE.md
 * "Configuration changes must clearly show version, effective date, approver,
 * and audit requirement."
 */
export function ConfigVersionMeta({ version, effectiveDate, approvedBy }: ConfigVersionMetaProps) {
  return (
    <div className="mb-4 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-md bg-surface-sunken p-3 text-xs text-secondary">
      <span>
        Version <strong>{version}</strong>
      </span>
      <span>Effective {formatDate(effectiveDate)}</span>
      <span>Approved by {approvedBy}</span>
      <span className="flex items-center gap-1 text-brand-600 dark:text-brand-400">
        <ShieldCheck className="h-3.5 w-3.5" aria-hidden="true" />
        Changes are recorded in the audit log
      </span>
    </div>
  );
}
