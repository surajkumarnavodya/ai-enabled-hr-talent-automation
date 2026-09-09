import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { StatusBadge } from "@/components/common/StatusBadge";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { Button } from "@/components/ui/Button";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { usePermissions } from "@/hooks/usePermissions";
import { useOffer, useApproveOffer } from "@/features/offers/useOffers";

export default function OfferApprovalPage() {
  const { offerId } = useParams<{ offerId: string }>();
  const navigate = useNavigate();
  const { data: offer, isLoading, isError, error, refetch } = useOffer(offerId);
  const approveOffer = useApproveOffer(offerId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (!hasPermission("offer.approve")) {
    return <PermissionDenied message="Approving offers requires HR Admin permissions." />;
  }
  if (isLoading) return <LoadingState label="Loading offer" />;
  if (isError || !offer) return <ErrorState error={error} onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title="Offer approval"
        breadcrumbs={[{ label: "Offers", to: "/offers" }, { label: "Approval" }]}
        actions={<StatusBadge status={offer.status} tone="warning" />}
      />

      <div className="max-w-lg rounded-lg border border-slate-200 p-6 dark:border-slate-800">
        <p className="mb-4 text-sm text-slate-600 dark:text-slate-400">
          Approving this offer authorizes HrAutomation.Api to allow it to be sent to the candidate.
          This is a mandatory human decision — the UI does not send the offer itself.
        </p>
        {offer.status === "PendingApproval" && (
          <Button onClick={() => setConfirmOpen(true)}>Approve offer</Button>
        )}
      </div>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Approve offer"
        description="Confirm approval of this offer for sending."
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          await approveOffer.mutateAsync();
          setConfirmOpen(false);
          navigate(`/offers/${offerId}`);
        }}
      />
    </>
  );
}
