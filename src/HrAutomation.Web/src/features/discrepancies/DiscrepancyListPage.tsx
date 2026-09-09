import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useDiscrepancyList, type Discrepancy } from "@/features/discrepancies/useDiscrepancies";
import type { DataTableColumn } from "@/types/ui";
import { severityTone } from "@/lib/formatters";

export default function DiscrepancyListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useDiscrepancyList();

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
        rows={data?.items ?? []}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No open discrepancies"
        onRowClick={(row) => navigate(`/discrepancies/${row.id}`)}
      />
    </>
  );
}
