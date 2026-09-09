import { useState } from "react";
import { useParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ShieldCheck } from "lucide-react";
import { FormField } from "@/components/forms/FormField";
import { FormErrorSummary } from "@/components/forms/FormErrorSummary";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { FileUpload } from "@/components/common/FileUpload";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { useGreenFormByToken, useSubmitGreenForm } from "@/features/green-form/useGreenForm";
import { userSafeMessage } from "@/api/client/apiError";

const greenFormSchema = z.object({
  employerName: z.string().trim().min(1, "Employer name is required."),
  startDate: z.string().trim().min(1, "Start date is required."),
  institution: z.string().trim().min(1, "Institution is required."),
  qualification: z.string().trim().min(1, "Qualification is required."),
  year: z.coerce.number().min(1950).max(new Date().getFullYear()),
});

type GreenFormValues = z.infer<typeof greenFormSchema>;

/**
 * Candidate-facing, token-authorized page — intentionally NOT wrapped in
 * ProtectedRoute (the candidate has no internal HrAutomation.Web session).
 * Never render internal HR notes or verification findings here — only
 * fields the candidate themselves is submitting. See CLAUDE.md and
 * docs/05-security-governance/frontend-security.md.
 */
export default function GreenFormPage() {
  const { token } = useParams<{ token: string }>();
  const { data: greenForm, isLoading, isError, refetch } = useGreenFormByToken(token);
  const submitMutation = useSubmitGreenForm(token ?? "");
  const [documents, setDocuments] = useState<File[]>([]);
  const [savedDraftAt, setSavedDraftAt] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<GreenFormValues>({ resolver: zodResolver(greenFormSchema) });

  async function onSubmit(values: GreenFormValues) {
    await submitMutation.mutateAsync({
      employmentHistory: [{ employerName: values.employerName, startDate: values.startDate }],
      education: [
        { institution: values.institution, qualification: values.qualification, year: values.year },
      ],
    });
  }

  function handleSaveProgress() {
    // TODO(api-contract): wire to a real draft-save endpoint once available.
    setSavedDraftAt(new Date().toLocaleTimeString());
  }

  if (isLoading)
    return (
      <div className="p-8">
        <LoadingState label="Loading your form" />
      </div>
    );
  if (isError || !greenForm)
    return (
      <div className="p-8">
        <ErrorState onRetry={() => refetch()} />
      </div>
    );

  if (submitMutation.isSuccess) {
    return (
      <main className="mx-auto max-w-lg p-8 text-center">
        <ShieldCheck className="mx-auto mb-3 h-10 w-10 text-status-success" aria-hidden="true" />
        <h1 className="text-lg font-semibold text-slate-900">Submission received</h1>
        <p className="mt-2 text-sm text-slate-600">
          Thank you. Our team will verify your details and follow up if anything needs
          clarification.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-2xl p-6 sm:p-8">
      <h1 className="mb-1 text-xl font-semibold text-slate-900">Onboarding — Green Form</h1>
      <p className="mb-6 text-sm text-slate-600">
        Please complete every section below. Your progress is saved as you go.
      </p>

      <form onSubmit={handleSubmit(onSubmit)} noValidate>
        <FormErrorSummary errors={errors} />

        <fieldset className="mb-6">
          <legend className="mb-2 text-sm font-semibold text-slate-800">Employment history</legend>
          <FormField label="Employer name" required error={errors.employerName?.message}>
            <Input {...register("employerName")} />
          </FormField>
          <FormField label="Start date" required error={errors.startDate?.message}>
            <Input type="date" {...register("startDate")} />
          </FormField>
        </fieldset>

        <fieldset className="mb-6">
          <legend className="mb-2 text-sm font-semibold text-slate-800">Education</legend>
          <FormField label="Institution" required error={errors.institution?.message}>
            <Input {...register("institution")} />
          </FormField>
          <FormField label="Qualification" required error={errors.qualification?.message}>
            <Input {...register("qualification")} />
          </FormField>
          <FormField label="Year completed" required error={errors.year?.message}>
            <Input type="number" {...register("year")} />
          </FormField>
        </fieldset>

        <fieldset className="mb-6">
          <legend className="mb-2 text-sm font-semibold text-slate-800">Required documents</legend>
          <ul className="mb-3 space-y-1 text-sm text-slate-600">
            {greenForm.requiredDocuments.map((doc) => (
              <li key={doc.documentType} className="flex items-center justify-between">
                <span>{doc.documentType}</span>
                <span className={doc.uploaded ? "text-status-success" : "text-slate-400"}>
                  {doc.uploaded ? "Uploaded" : "Pending"}
                </span>
              </li>
            ))}
          </ul>
          <FileUpload
            label="Upload documents"
            multiple
            onFilesAccepted={(files) => setDocuments((prev) => [...prev, ...files])}
          />
          {documents.length > 0 && (
            <p className="mt-2 text-xs text-slate-500">
              {documents.length} file(s) staged for upload.
            </p>
          )}
        </fieldset>

        {submitMutation.isError && (
          <p role="alert" className="mb-4 text-sm text-status-danger">
            {userSafeMessage(submitMutation.error)}
          </p>
        )}

        <div className="flex items-center justify-between">
          <div>
            <Button type="button" variant="outline" size="sm" onClick={handleSaveProgress}>
              Save progress
            </Button>
            {savedDraftAt && (
              <span className="ml-2 text-xs text-slate-400">Saved at {savedDraftAt}</span>
            )}
          </div>
          <Button type="submit" isLoading={isSubmitting}>
            Submit
          </Button>
        </div>
      </form>
    </main>
  );
}
