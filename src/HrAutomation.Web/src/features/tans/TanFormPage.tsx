import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useNavigate, useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { FormField } from "@/components/forms/FormField";
import { FormSection } from "@/components/forms/FormSection";
import { FormErrorSummary } from "@/components/forms/FormErrorSummary";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { useCreateTan } from "@/features/tans/useTans";
import { userSafeMessage } from "@/api/client/apiError";

const tanFormSchema = z.object({
  title: z.string().trim().min(1, "Title is required."),
  location: z.string().trim().min(1, "Location is required."),
  grade: z.string().trim().min(1, "Grade is required."),
  budgetMin: z.coerce.number().min(0, "Budget minimum must be zero or more."),
  budgetMax: z.coerce.number().min(0, "Budget maximum must be zero or more."),
  mandatorySkills: z.string().trim().min(1, "At least one mandatory skill is required."),
  preferredSkills: z.string().trim().optional(),
  rawDescription: z.string().trim().min(1, "A description is required."),
});

type TanFormValues = z.infer<typeof tanFormSchema>;

function toJsonArray(csv: string): string {
  const values = csv
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return JSON.stringify(values);
}

/**
 * Handles /tans/new (create only — /tans/:tanId/edit routes here too but edit
 * is not implemented: there is no PATCH/PUT endpoint on HrAutomation.Api for
 * an existing TAN, so this form always creates). Client-side validation here
 * is a UX convenience only — HrAutomation.Api independently validates and is
 * the final authority (see docs/04-api/frontend-api-integration.md).
 *
 * NOTE (see DECISIONS_REQUIRED.md DEC-004): location/grade/budget fields are
 * sent to the API but are not currently persisted — recruitment.JobRequisition
 * has no backing column for them yet. They are still collected here so the
 * form is ready once that gap is resolved, but the created TAN's detail page
 * will not show them back.
 */
export default function TanFormPage() {
  const { tanId } = useParams<{ tanId: string }>();
  const isEdit = Boolean(tanId);
  const navigate = useNavigate();
  const createTan = useCreateTan();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<z.input<typeof tanFormSchema>, unknown, TanFormValues>({
    resolver: zodResolver(tanFormSchema),
  });

  async function onSubmit(values: TanFormValues) {
    const response = await createTan.mutateAsync({
      title: values.title,
      location: values.location,
      grade: values.grade,
      budget_min: values.budgetMin,
      budget_max: values.budgetMax,
      interview_stages_count: 2,
      client_interview_required: false,
      mandatory_criteria_json: toJsonArray(values.mandatorySkills),
      preferred_criteria_json: toJsonArray(values.preferredSkills ?? ""),
      raw_description: values.rawDescription,
    });

    // Server-authoritative result only — never a locally-invented id/status.
    // TanDetailPage re-fetches GET /v1/tans/{tanId} on mount, so navigating
    // here is the "read back what was actually persisted" step.
    if (response.tan_id) {
      navigate(`/tans/${response.tan_id}`);
    } else {
      navigate("/tans");
    }
  }

  return (
    <>
      <PageHeader
        title={isEdit ? "Edit TAN" : "New TAN"}
        breadcrumbs={[{ label: "TANs", to: "/tans" }, { label: isEdit ? "Edit" : "New" }]}
        description={
          isEdit
            ? "Editing an existing TAN is not available yet — no update endpoint exists on HrAutomation.Api."
            : undefined
        }
      />

      {isEdit ? (
        <p className="text-sm text-secondary">
          Feature not available yet. Go back to{" "}
          <a className="text-brand-600 underline" href="/tans">
            TANs
          </a>
          .
        </p>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} noValidate className="max-w-2xl">
          <FormErrorSummary errors={errors} />

          <FormSection title="Role details" description="Basic identification for this requisition.">
            <FormField label="Title" required error={errors.title?.message}>
              <Input {...register("title")} />
            </FormField>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <FormField label="Location" required error={errors.location?.message}>
                <Input {...register("location")} />
              </FormField>
              <FormField label="Grade" required error={errors.grade?.message}>
                <Input {...register("grade")} />
              </FormField>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <FormField label="Budget (min)" required error={errors.budgetMin?.message}>
                <Input type="number" step="1000" {...register("budgetMin")} />
              </FormField>
              <FormField label="Budget (max)" required error={errors.budgetMax?.message}>
                <Input type="number" step="1000" {...register("budgetMax")} />
              </FormField>
            </div>
          </FormSection>

          <FormSection
            title="Requirements"
            description="Used by AI-assisted candidate matching once this TAN is approved."
          >
            <FormField
              label="Mandatory skills"
              required
              hint="Comma-separated"
              error={errors.mandatorySkills?.message}
            >
              <Input {...register("mandatorySkills")} />
            </FormField>
            <FormField
              label="Preferred skills"
              hint="Comma-separated"
              error={errors.preferredSkills?.message}
            >
              <Input {...register("preferredSkills")} />
            </FormField>
            <FormField label="Description" required error={errors.rawDescription?.message}>
              <Input {...register("rawDescription")} />
            </FormField>
          </FormSection>

          {createTan.isError && (
            <p role="alert" className="mt-4 text-sm text-status-danger">
              {userSafeMessage(createTan.error)}
            </p>
          )}

          <div className="mt-6 flex justify-end gap-2 border-t border-subtle pt-4">
            <Button type="button" variant="outline" onClick={() => navigate("/tans")}>
              Cancel
            </Button>
            <Button type="submit" isLoading={isSubmitting}>
              Save TAN
            </Button>
          </div>
        </form>
      )}
    </>
  );
}
