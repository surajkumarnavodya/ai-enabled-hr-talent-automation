import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Button } from "@/components/ui/Button";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { usePermissions } from "@/hooks/usePermissions";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { useCreateOffer } from "@/features/offers/useOffers";
import { userSafeMessage } from "@/api/client/apiError";
import type { AgentActionResponse } from "@/types/api";

export default function OfferNewPage() {
  const { applicationId } = useParams<{ applicationId: string }>();
  const navigate = useNavigate();
  const { hasPermission } = usePermissions();
  const createOffer = useCreateOffer(applicationId ?? "");
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (!hasPermission("offer.approve") && !hasPermission("offer.send")) {
    return (
      <PermissionDenied message="Drafting an offer requires HR Admin or Recruiter permissions." />
    );
  }

  return (
    <>
      <PageHeader
        title="New offer"
        breadcrumbs={[{ label: "Offers", to: "/offers" }, { label: "New" }]}
        description="Draft only — server approval is required before this offer can be sent."
      />

      <div className="max-w-lg rounded-lg border border-slate-200 p-6 dark:border-slate-800">
        <p className="mb-2 text-sm text-slate-600 dark:text-slate-400">
          Creates a draft offer for this candidate and immediately submits it for the standard
          approval workflow.
        </p>
        <p className="mb-4 text-xs text-slate-400">
          Compensation entry is not available yet — offer.OfferCompensation is a restricted table
          with no write path in this build. Set compensation through the existing offline process
          before sending this offer.
        </p>

        {createOffer.isError && (
          <p role="alert" className="mb-4 text-sm text-status-danger">
            {userSafeMessage(createOffer.error)}
          </p>
        )}

        <div className="flex justify-end gap-2">
          <Button type="button" variant="outline" onClick={() => navigate("/offers")}>
            Cancel
          </Button>
          <Button onClick={() => setConfirmOpen(true)} isLoading={createOffer.isPending}>
            Create draft offer
          </Button>
        </div>
      </div>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Create draft offer"
        description="Create a draft offer for this candidate and submit it for approval?"
        confirmLabel="Create draft offer"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          const response = (await createOffer.mutateAsync()) as AgentActionResponse;
          setConfirmOpen(false);
          if (response.offer_id) {
            navigate(`/offers/${response.offer_id}`);
          } else {
            navigate("/offers");
          }
        }}
      />
    </>
  );
}
