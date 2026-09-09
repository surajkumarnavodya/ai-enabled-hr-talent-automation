import { ConfigVersionMeta } from "@/features/administration/ConfigVersionMeta";
import { EmptyState } from "@/components/common/EmptyState";

/**
 * UI placeholder only, per CLAUDE.md scope. Backs onto
 * config/schemas/workflow-config.schema.json and config/schemas/approval-matrix.schema.json
 * at the repository root once an admin-facing config API exists.
 */
export default function AdminConfigurationPage() {
  return (
    <div>
      <ConfigVersionMeta version="1.0.0" effectiveDate="2026-09-07" approvedBy="Demo HR Admin" />
      <EmptyState
        title="Workflow & approval-matrix configuration"
        description="Editing tenant settings, workflow stages, and the approval matrix will be available once the admin configuration API is implemented."
      />
    </div>
  );
}
