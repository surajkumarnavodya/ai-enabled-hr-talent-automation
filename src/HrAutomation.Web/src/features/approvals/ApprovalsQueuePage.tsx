import { useState } from "react";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { Button } from "@/components/ui/Button";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import {
  usePendingApprovals,
  useDecideApproval,
  type PendingApproval,
} from "@/features/approvals/useApprovals";
import type { DataTableColumn } from "@/types/ui";
import { formatDateTime } from "@/lib/dateUtils";

export default function ApprovalsQueuePage() {
  const { data, isLoading, isError, refetch } = usePendingApprovals();
  const decideMutation = useDecideApproval();
  const [target, setTarget] = useState<{
    item: PendingApproval;
    decision: "approved" | "rejected";
  } | null>(null);

  const columns: DataTableColumn<PendingApproval>[] = [
    { id: "subjectLabel", header: "Item", sortable: true, accessor: (row) => row.subjectLabel },
    { id: "action", header: "Action requested", accessor: (row) => row.action },
    {
      id: "requestedAt",
      header: "Requested",
      sortable: true,
      accessor: (row) => formatDateTime(row.requestedAt),
    },
    {
      id: "actions",
      header: "",
      accessor: (row) => (
        <div className="flex gap-2">
          <Button size="sm" onClick={() => setTarget({ item: row, decision: "approved" })}>
            Approve
          </Button>
          <Button
            size="sm"
            variant="danger"
            onClick={() => setTarget({ item: row, decision: "rejected" })}
          >
            Reject
          </Button>
        </div>
      ),
    },
  ];

  return (
    <>
      <PageHeader
        title="Approvals"
        description="Your pending approval work queue, as authorized by HrAutomation.Api."
      />
      <DataTable
        columns={columns}
        rows={data ?? []}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => refetch()}
        emptyTitle="Nothing pending your approval"
      />

      <ConfirmActionDialog
        open={target !== null}
        title={target?.decision === "approved" ? "Approve" : "Reject"}
        description={
          target
            ? `${target.decision === "approved" ? "Approve" : "Reject"} "${target.item.subjectLabel}" — ${target.item.action}?`
            : ""
        }
        destructive={target?.decision === "rejected"}
        onCancel={() => setTarget(null)}
        onConfirm={async () => {
          if (!target) return;
          await decideMutation.mutateAsync({ id: target.item.id, decision: target.decision });
          setTarget(null);
        }}
      />
    </>
  );
}
