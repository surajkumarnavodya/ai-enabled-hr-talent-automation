import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useNavigate, useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { FormField } from "@/components/forms/FormField";
import { FormErrorSummary } from "@/components/forms/FormErrorSummary";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { usePermissions } from "@/hooks/usePermissions";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { useCreateOffer } from "@/features/offers/useOffers";
import { userSafeMessage } from "@/api/client/apiError";

const offerSchema = z.object({
  compensationRef: z.string().trim().min(1, "A compensation system reference is required."),
  templateVersion: z.string().trim().min(1, "Template version is required."),
});

type OfferFormValues = z.infer<typeof offerSchema>;

export default function OfferNewPage() {
  const { applicationId } = useParams<{ applicationId: string }>();
  const navigate = useNavigate();
  const { hasPermission } = usePermissions();
  const createOffer = useCreateOffer(applicationId ?? "");

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<OfferFormValues>({ resolver: zodResolver(offerSchema) });

  // Grade/compensation fields are permission-gated: only roles that can approve
  // offers may draft the compensation reference at all (see hooks/usePermissions.ts).
  if (!hasPermission("offer.approve") && !hasPermission("offer.send")) {
    return (
      <PermissionDenied message="Drafting an offer requires HR Admin or Recruiter permissions." />
    );
  }

  async function onSubmit(values: OfferFormValues) {
    const offer = await createOffer.mutateAsync(values);
    navigate(`/offers/${offer.id}`);
  }

  return (
    <>
      <PageHeader
        title="New offer"
        breadcrumbs={[{ label: "Offers", to: "/offers" }, { label: "New" }]}
        description="Draft only — server approval is required before this offer can be sent."
      />

      <form onSubmit={handleSubmit(onSubmit)} noValidate className="max-w-md">
        <FormErrorSummary errors={errors} />

        <FormField
          label="Compensation reference"
          required
          hint="Reference into the external compensation system — no figures are entered here."
          error={errors.compensationRef?.message}
        >
          <Input {...register("compensationRef")} placeholder="e.g. comp-ref-G4-2026" />
        </FormField>
        <FormField label="Offer template version" required error={errors.templateVersion?.message}>
          <Input {...register("templateVersion")} placeholder="e.g. offer-template-v2" />
        </FormField>

        {createOffer.isError && (
          <p role="alert" className="mb-4 text-sm text-status-danger">
            {userSafeMessage(createOffer.error)}
          </p>
        )}

        <div className="flex justify-end gap-2">
          <Button type="button" variant="outline" onClick={() => navigate("/offers")}>
            Cancel
          </Button>
          <Button type="submit" isLoading={isSubmitting}>
            Save draft
          </Button>
        </div>
      </form>
    </>
  );
}
