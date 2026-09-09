import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useDiscrepancyList } from "@/features/discrepancies/useDiscrepancies";
import type { DataTableColumn } from "@/types/ui";
import type { Discrepancy } from "@/types/workflow";
import { severityTone } from "@/lib/formatters";

export default function DiscrepancyListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, refetch } = useDiscrepancyList();

  const columns: DataTableColumn<Discrepancy>[] = [
    { id: "type", header: "Type", sortable: true, accessor: (row) => row.type },
    {
      id: "severity",
      header: "Severity",
      accessor: (row) => <StatusBadge status={row.severity} tone={severityTone(row.severity)} />,
    },
    {
      id: "status",
      header: "Status",
      accessor: (row) => <StatusBadge status={row.status} tone="neutral" />,
    },
  ];

  return (
    <>
      <PageHeader
        title="Discrepancies"
        description="Document/data verification discrepancies requiring action."
      />
      <DataTable
        columns={columns}
        rows={data ?? []}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => refetch()}
        emptyTitle="No open discrepancies"
        onRowClick={(row) => navigate(`/discrepancies/${row.id}`)}
      />
    </>
  );
}
