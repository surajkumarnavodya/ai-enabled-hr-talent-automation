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
import type { OfferStatus } from "@/types/workflow";

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

export default function OfferDetailPage() {
  const { offerId } = useParams<{ offerId: string }>();
  const { data: offer, isLoading, isError, refetch } = useOffer(offerId);
  const sendOffer = useSendOffer(offerId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (isLoading) return <LoadingState label="Loading offer" />;
  if (isError || !offer) return <ErrorState onRetry={() => refetch()} />;

  const canSend = hasPermission("offer.send") && offer.status === "approved";

  return (
    <>
      <PageHeader
        title={`Offer ${offer.id.slice(0, 8)}`}
        breadcrumbs={[{ label: "Offers", to: "/offers" }, { label: offer.id.slice(0, 8) }]}
        actions={
          <>
            <StatusBadge status={offer.status} tone={OFFER_STATUS_TONE[offer.status]} />
            {offer.status !== "approved" &&
              offer.status !== "sent" &&
              offer.status !== "accepted" && (
                <ButtonLink to={`/offers/${offer.id}/approval`} variant="outline" size="sm">
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

      {offer.status === "drafted" && (
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
          <CardContent className="text-sm">
            <p className="text-slate-500">
              Reference (server-resolved, no client-side computation):
            </p>
            <p className="mt-1 font-mono text-slate-800 dark:text-slate-200">
              {offer.compensationRef}
            </p>
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
              status={offer.status === "accepted" ? "accepted" : "awaiting_response"}
              tone={offer.status === "accepted" ? "success" : "neutral"}
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
