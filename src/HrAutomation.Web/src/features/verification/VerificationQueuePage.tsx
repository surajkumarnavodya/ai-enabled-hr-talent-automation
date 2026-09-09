import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import {
  useVerificationQueue,
  type VerificationQueueItem,
} from "@/features/verification/useVerification";
import type { DataTableColumn } from "@/types/ui";
import { formatDateTime } from "@/lib/dateUtils";

// Mirrors CK_VerificationCase_Status exactly — Open, InProgress, Completed, Cancelled.
const STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning"> = {
  Open: "warning",
  InProgress: "info",
  Completed: "success",
  Cancelled: "neutral",
};

export default function VerificationQueuePage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useVerificationQueue();

  const columns: DataTableColumn<VerificationQueueItem>[] = [
    {
      id: "candidate_name",
      header: "Candidate",
      sortable: true,
      accessor: (row) => row.candidate_name,
    },
    {
      id: "opened_at",
      header: "Opened",
      sortable: true,
      accessor: (row) => formatDateTime(row.opened_at),
    },
    {
      id: "status",
      header: "Status",
      accessor: (row) => (
        <StatusBadge status={row.status} tone={STATUS_TONE[row.status] ?? "neutral"} />
      ),
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
        rows={data?.items ?? []}
        getRowId={(row) => row.application_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="Nothing pending verification"
        onRowClick={(row) => navigate(`/verification/${row.application_id}`)}
      />
    </>
  );
}
