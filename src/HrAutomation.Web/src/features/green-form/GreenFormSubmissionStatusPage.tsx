import { useParams } from "react-router-dom";
import { ShieldCheck } from "lucide-react";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { useGreenFormSubmission } from "@/features/green-form/useGreenForm";

/** Candidate-facing status check — never surfaces internal HR notes or verification findings. */
export default function GreenFormSubmissionStatusPage() {
  const { submissionId } = useParams<{ submissionId: string }>();
  const { data, isLoading, isError, error, refetch } = useGreenFormSubmission(submissionId);

  if (isLoading)
    return (
      <div className="p-8">
        <LoadingState label="Loading status" />
      </div>
    );
  if (isError || !data)
    return (
      <div className="p-8">
        <ErrorState error={error} onRetry={() => refetch()} />
      </div>
    );

  return (
    <main className="mx-auto max-w-lg p-8 text-center">
      <ShieldCheck className="mx-auto mb-3 h-10 w-10 text-brand-600" aria-hidden="true" />
      <h1 className="text-lg font-semibold text-primary">Submission status</h1>
      <p className="mt-2 text-sm text-secondary">
        Your submission is currently: <strong>{data.status}</strong>
      </p>
      <p className="mt-4 text-xs text-tertiary">
        We'll contact you directly if any additional information or documents are needed.
      </p>
    </main>
  );
}
