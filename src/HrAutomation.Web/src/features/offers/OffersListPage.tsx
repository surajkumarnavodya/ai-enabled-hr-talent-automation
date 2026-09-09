import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useOfferList } from "@/features/offers/useOffers";
import type { DataTableColumn } from "@/types/ui";
import type { Offer, OfferStatus } from "@/types/workflow";

const OFFER_STATUS_TONE: Record<
  OfferStatus,
  "neutral" | "info" | "success" | "warning" | "danger"
> = {
  drafted: "neutral",
  pending_approval: "warning",
  approved: "info",
  sent: "info",
  accepted: "success",
  declined: "danger",
  expired: "neutral",
};

export default function OffersListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, refetch } = useOfferList();

  const columns: DataTableColumn<Offer>[] = [
    { id: "id", header: "Offer", accessor: (row) => row.id.slice(0, 8) },
    { id: "templateVersion", header: "Template", accessor: (row) => row.templateVersion },
    {
      id: "status",
      header: "Status",
      accessor: (row) => <StatusBadge status={row.status} tone={OFFER_STATUS_TONE[row.status]} />,
    },
  ];

  return (
    <>
      <PageHeader title="Offers" description="Draft, approve, and track candidate offers." />
      <DataTable
        columns={columns}
        rows={data ?? []}
        getRowId={(row) => row.id}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => refetch()}
        emptyTitle="No offers yet"
        onRowClick={(row) => navigate(`/offers/${row.id}`)}
      />
    </>
  );
}
