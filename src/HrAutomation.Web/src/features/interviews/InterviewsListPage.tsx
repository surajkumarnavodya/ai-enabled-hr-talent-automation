import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useInterviewList, type Interview } from "@/features/interviews/useInterviews";
import type { DataTableColumn } from "@/types/ui";
import type { InterviewStatus } from "@/types/workflow";
import { formatDateTime } from "@/lib/dateUtils";

const STATUS_TONE: Record<InterviewStatus, "neutral" | "info" | "success" | "danger"> = {
  scheduled: "info",
  rescheduled: "info",
  completed: "success",
  cancelled: "neutral",
  no_show: "danger",
};

export default function InterviewsListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, refetch } = useInterviewList();

  const columns: DataTableColumn<Interview>[] = [
    {
      id: "candidateName",
      header: "Candidate",
      sortable: true,
      accessor: (row) => row.candidateName,
    },
    { id: "stage", header: "Stage", accessor: (row) => row.stage },
    {
      id: "scheduledAt",
      header: "Scheduled",
      sortable: true,
      accessor: (row) => (row.scheduledAt ? formatDateTime(row.scheduledAt) : "Not scheduled"),
    },
    {
      id: "status",
      header: "Status",
      accessor: (row) => <StatusBadge status={row.status} tone={STATUS_TONE[row.status]} />,
    },
  ];

  return (
    <>
      <PageHeader
        title="Interviews"
        description="L1, L2, and client interview scheduling and status."
      />
      <DataTable
        columns={columns}
        rows={data ?? []}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => refetch()}
        emptyTitle="No interviews scheduled"
        onRowClick={(row) => navigate(`/interviews/${row.id}`)}
      />
    </>
  );
}
