import { useState } from "react";
import { PageHeader } from "@/components/common/PageHeader";
import { Input } from "@/components/ui/Input";
import { AuditTimeline } from "@/components/common/AuditTimeline";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { usePermissions } from "@/hooks/usePermissions";
import { useAuditLog, type AuditFilters } from "@/features/audit/useAudit";

export default function AuditPage() {
  const { hasPermission } = usePermissions();
  const [filters, setFilters] = useState<AuditFilters>({});
  const { data, isLoading, isError, error, refetch } = useAuditLog(filters);

  if (!hasPermission("audit.read")) {
    return (
      <PermissionDenied message="Viewing the audit log requires HR Admin or Hiring Manager permissions." />
    );
  }

  return (
    <>
      <PageHeader
        title="Audit Trail"
        description="Workflow timeline across TANs, candidates, and approvals."
      />

      <div className="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <Input
          placeholder="Entity type"
          aria-label="Filter by entity type"
          onChange={(e) => setFilters((f) => ({ ...f, entityType: e.target.value || undefined }))}
        />
        <Input
          placeholder="TAN ID"
          aria-label="Filter by TAN"
          onChange={(e) => setFilters((f) => ({ ...f, tanId: e.target.value || undefined }))}
        />
        <Input
          placeholder="Candidate ID"
          aria-label="Filter by candidate"
          onChange={(e) => setFilters((f) => ({ ...f, candidateId: e.target.value || undefined }))}
        />
        <Input
          placeholder="Action"
          aria-label="Filter by action"
          onChange={(e) => setFilters((f) => ({ ...f, action: e.target.value || undefined }))}
        />
        <Input
          placeholder="Actor"
          aria-label="Filter by actor"
          onChange={(e) => setFilters((f) => ({ ...f, actor: e.target.value || undefined }))}
        />
      </div>

      {isLoading && <LoadingState label="Loading audit log" />}
      {isError && <ErrorState error={error} onRetry={() => refetch()} />}
      {data && <AuditTimeline entries={data} />}
    </>
  );
}
