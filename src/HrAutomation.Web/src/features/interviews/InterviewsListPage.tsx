import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useInterviewList, type Interview } from "@/features/interviews/useInterviews";
import type { DataTableColumn } from "@/types/ui";
import { formatDateTime } from "@/lib/dateUtils";

// Mirrors CK_Interview_Status (recruitment.Interview.Status) exactly — Scheduled, Completed,
// Cancelled, NoShow. Falls back to "neutral" for any value not in this set.
const STATUS_TONE: Record<string, "neutral" | "info" | "success" | "danger"> = {
  Scheduled: "info",
  Completed: "success",
  Cancelled: "neutral",
  NoShow: "danger",
};

export default function InterviewsListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useInterviewList();

  const columns: DataTableColumn<Interview>[] = [
    {
      id: "candidate_name",
      header: "Candidate",
      sortable: true,
      accessor: (row) => row.candidate_name,
    },
    { id: "stage", header: "Stage", accessor: (row) => row.stage },
    {
      id: "scheduled_at",
      header: "Scheduled",
      sortable: true,
      accessor: (row) => (row.scheduled_at ? formatDateTime(row.scheduled_at) : "Not scheduled"),
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
        title="Interviews"
        description="L1, L2, and client interview scheduling and status."
      />
      <DataTable
        columns={columns}
        rows={data?.items ?? []}
        getRowId={(row) => row.interview_round_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No interviews scheduled"
        onRowClick={(row) => navigate(`/interviews/${row.interview_round_id}`)}
      />
    </>
  );
}
