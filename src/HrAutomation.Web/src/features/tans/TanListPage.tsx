import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { useTanList } from "@/features/tans/useTans";
import type { DataTableColumn } from "@/types/ui";
import type { Tan } from "@/types/workflow";

/** Mirrors recruitment.JobRequisition.RequisitionStatusCode's real values exactly
 * (Draft, PendingApproval, Approved, ActiveSourcing, OnHold, ClosedFilled, Cancelled). */
const TAN_STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning"> = {
  Draft: "neutral",
  PendingApproval: "warning",
  Approved: "success",
  ActiveSourcing: "info",
  OnHold: "warning",
  ClosedFilled: "neutral",
  Cancelled: "neutral",
};

export default function TanListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useTanList();

  const columns: DataTableColumn<Tan>[] = [
    { id: "tan_number", header: "TAN #", sortable: true, accessor: (row) => row.tan_number },
    { id: "title", header: "Title", sortable: true, accessor: (row) => row.title },
    {
      id: "status",
      header: "Status",
      accessor: (row) => (
        <StatusBadge status={row.status} tone={TAN_STATUS_TONE[row.status] ?? "neutral"} />
      ),
    },
  ];

  return (
    <>
      <PageHeader
        title="TANs / Job Requisitions"
        actions={<ButtonLink to="/tans/new">New TAN</ButtonLink>}
      />
      <DataTable
        columns={columns}
        rows={data?.items ?? []}
        getRowId={(row) => row.tan_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No TANs yet"
        emptyDescription="Create a TAN to start sourcing candidates against a job description."
        onRowClick={(row) => navigate(`/tans/${row.tan_id}`)}
      />
    </>
  );
}
