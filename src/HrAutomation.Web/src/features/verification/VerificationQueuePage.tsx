import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useVerificationQueue } from "@/features/verification/useVerification";
import type { DataTableColumn } from "@/types/ui";
import type { VerificationOutcome } from "@/types/workflow";
import { formatDateTime } from "@/lib/dateUtils";
import type { VerificationQueueItem } from "@/features/verification/useVerification";

const OUTCOME_TONE: Record<VerificationOutcome, "success" | "danger" | "warning"> = {
  pass: "success",
  fail: "danger",
  needs_review: "warning",
};

export default function VerificationQueuePage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, refetch } = useVerificationQueue();

  const columns: DataTableColumn<VerificationQueueItem>[] = [
    {
      id: "candidateName",
      header: "Candidate",
      sortable: true,
      accessor: (row) => row.candidateName,
    },
    {
      id: "submittedAt",
      header: "Submitted",
      sortable: true,
      accessor: (row) => formatDateTime(row.submittedAt),
    },
    {
      id: "outcome",
      header: "Outcome",
      accessor: (row) => <StatusBadge status={row.outcome} tone={OUTCOME_TONE[row.outcome]} />,
    },
  ];

  return (
    <>
      <PageHeader
        title="Document Verification"
        description="Employment, education, and document verification queue."
      />
      <DataTable
        columns={columns}
        rows={data ?? []}
        getRowId={(row) => row.applicationId}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => refetch()}
        emptyTitle="Nothing pending verification"
        onRowClick={(row) => navigate(`/verification/${row.applicationId}`)}
      />
    </>
  );
}
