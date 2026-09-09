import { useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useOfferList, type Offer } from "@/features/offers/useOffers";
import type { DataTableColumn } from "@/types/ui";

// Mirrors ref.OfferStatus.Code exactly — Draft, PendingApproval, Approved, Sent, Viewed,
// Accepted, Declined, Expired, Withdrawn. Falls back to "neutral" for any unlisted value.
const OFFER_STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning" | "danger"> = {
  Draft: "neutral",
  PendingApproval: "warning",
  Approved: "info",
  Sent: "info",
  Viewed: "info",
  Accepted: "success",
  Declined: "danger",
  Expired: "neutral",
  Withdrawn: "neutral",
};

export default function OffersListPage() {
  const navigate = useNavigate();
  const { data, isLoading, isError, error, refetch } = useOfferList();

  const columns: DataTableColumn<Offer>[] = [
    { id: "offer_number", header: "Offer", accessor: (row) => row.offer_number },
    {
      id: "status",
      header: "Status",
      accessor: (row) => (
        <StatusBadge status={row.status} tone={OFFER_STATUS_TONE[row.status] ?? "neutral"} />
      ),
    },
  ];

  return (
    <>
      <PageHeader title="Offers" description="Draft, approve, and track candidate offers." />
      <DataTable
        columns={columns}
        rows={data?.items ?? []}
        getRowId={(row) => row.offer_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No offers yet"
        onRowClick={(row) => navigate(`/offers/${row.offer_id}`)}
      />
    </>
  );
}
