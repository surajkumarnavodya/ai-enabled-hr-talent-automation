import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useConversionList } from "@/features/employee-conversion/useEmployeeConversion";
import type { DataTableColumn } from "@/types/ui";
import type { ConversionCandidate } from "@/features/employee-conversion/useEmployeeConversion";

export default function EmployeeConversionListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useConversionList();

  const columns: DataTableColumn<ConversionCandidate>[] = [
    {
      id: "candidate_name",
      header: "Candidate",
      sortable: true,
      accessor: (row) => row.candidate_name,
    },
    {
      id: "eligible",
      header: "Eligibility",
      accessor: (row) => (
        <StatusBadge
          status={row.eligible ? "eligible" : "pending"}
          tone={row.eligible ? "success" : "warning"}
        />
      ),
    },
  ];

  return (
    <>
      <PageHeader
        title="Employee Conversion"
        description="Candidates pending conversion to employee status."
      />
      <DataTable
        columns={columns}
        rows={data?.items ?? []}
        getRowId={(row) => row.application_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No pending conversions"
        onRowClick={(row) => navigate(`/employee-conversion/${row.application_id}`)}
      />
    </>
  );
}
