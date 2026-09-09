import { useState } from "react";
import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { StatusBadge } from "@/components/common/StatusBadge";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { usePermissions } from "@/hooks/usePermissions";
import { useOffer, useSendOffer } from "@/features/offers/useOffers";

// Mirrors ref.OfferStatus.Code exactly. Falls back to "neutral" for any unlisted value.
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

export default function OfferDetailPage() {
  const { offerId } = useParams<{ offerId: string }>();
  const { data: offer, isLoading, isError, error, refetch } = useOffer(offerId);
  const sendOffer = useSendOffer(offerId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (isLoading) return <LoadingState label="Loading offer" />;
  if (isError || !offer) return <ErrorState error={error} onRetry={() => refetch()} />;

  const canSend = hasPermission("offer.send") && offer.status === "Approved";

  return (
    <>
      <PageHeader
        title={`Offer ${offer.offer_number}`}
        breadcrumbs={[{ label: "Offers", to: "/offers" }, { label: offer.offer_number }]}
        actions={
          <>
            <StatusBadge status={offer.status} tone={OFFER_STATUS_TONE[offer.status] ?? "neutral"} />
            {offer.status !== "Approved" && offer.status !== "Sent" && offer.status !== "Accepted" && (
              <ButtonLink to={`/offers/${offer.offer_id}/approval`} variant="outline" size="sm">
                Approval status
              </ButtonLink>
            )}
            {canSend && (
              <Button size="sm" onClick={() => setConfirmOpen(true)}>
                Send offer
              </Button>
            )}
          </>
        }
      />

      {offer.status === "Draft" && (
        <p className="mb-4 rounded-md bg-amber-50 p-3 text-sm text-status-warning dark:bg-amber-950">
          Draft only — server approval is required before this offer can be sent.
        </p>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Compensation
            </h2>
          </CardHeader>
          <CardContent className="text-sm text-slate-500 dark:text-slate-400">
            Not available yet — offer.OfferCompensation has no write path in this build. See the
            existing offline compensation process for this offer.
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Candidate acceptance
            </h2>
          </CardHeader>
          <CardContent>
            <StatusBadge
              status={offer.status === "Accepted" ? "accepted" : "awaiting_response"}
              tone={offer.status === "Accepted" ? "success" : "neutral"}
            />
          </CardContent>
        </Card>
      </div>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Send offer"
        description="This sends the approved offer document to the candidate for acceptance and e-signature."
        confirmLabel="Send offer"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          await sendOffer.mutateAsync();
          setConfirmOpen(false);
        }}
      />
    </>
  );
}
