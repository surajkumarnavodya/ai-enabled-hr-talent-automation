import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useNavigate, useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { FormField } from "@/components/forms/FormField";
import { FormErrorSummary } from "@/components/forms/FormErrorSummary";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useSubmitInterviewFeedback } from "@/features/interviews/useInterviews";
import { userSafeMessage } from "@/api/client/apiError";

const feedbackSchema = z.object({
  outcome: z.enum(["select", "reject"]),
  communicationScore: z.coerce.number().min(1).max(5),
  technicalScore: z.coerce.number().min(1).max(5),
  notes: z.string().trim().min(1, "Notes are required for the audit record."),
});

type FeedbackFormValues = z.infer<typeof feedbackSchema>;

export default function InterviewFeedbackPage() {
  const { interviewId } = useParams<{ interviewId: string }>();
  const navigate = useNavigate();
  const submitFeedback = useSubmitInterviewFeedback(interviewId ?? "");
  const [submitted, setSubmitted] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<z.input<typeof feedbackSchema>, unknown, FeedbackFormValues>({
    resolver: zodResolver(feedbackSchema),
  });

  async function onSubmit(values: FeedbackFormValues) {
    await submitFeedback.mutateAsync(values);
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <>
        <PageHeader
          title="Feedback submitted"
          breadcrumbs={[{ label: "Interviews", to: "/interviews" }]}
        />
        <div className="max-w-md rounded-lg border border-slate-200 p-6 text-center dark:border-slate-800">
          <p className="mb-3 text-sm text-slate-700 dark:text-slate-300">
            Your feedback has been recorded. This candidate's application status is now:
          </p>
          <StatusBadge status="pending_hr_decision" tone="warning" label="Pending HR Decision" />
          <p className="mt-4">
            <Button variant="outline" size="sm" onClick={() => navigate("/interviews")}>
              Back to interviews
            </Button>
          </p>
        </div>
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="Interview feedback"
        breadcrumbs={[{ label: "Interviews", to: "/interviews" }, { label: "Feedback" }]}
        description="This records your recommendation only. HR makes the final progression decision."
      />

      <form onSubmit={handleSubmit(onSubmit)} noValidate className="max-w-lg">
        <FormErrorSummary errors={errors} />

        <FormField label="Recommendation" required error={errors.outcome?.message}>
          <Select {...register("outcome")} defaultValue="">
            <option value="" disabled>
              Choose…
            </option>
            <option value="select">Select — progress candidate</option>
            <option value="reject">Reject — close for this TAN</option>
          </Select>
        </FormField>
        <FormField label="Communication (1-5)" required error={errors.communicationScore?.message}>
          <Input type="number" min={1} max={5} {...register("communicationScore")} />
        </FormField>
        <FormField label="Technical (1-5)" required error={errors.technicalScore?.message}>
          <Input type="number" min={1} max={5} {...register("technicalScore")} />
        </FormField>
        <FormField label="Notes" required error={errors.notes?.message}>
          <textarea
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm dark:border-slate-700 dark:bg-slate-900"
            rows={4}
            {...register("notes")}
          />
        </FormField>

        {submitFeedback.isError && (
          <p role="alert" className="mb-4 text-sm text-status-danger">
            {userSafeMessage(submitFeedback.error)}
          </p>
        )}

        <div className="flex justify-end">
          <Button type="submit" isLoading={isSubmitting}>
            Submit feedback
          </Button>
        </div>
      </form>
    </>
  );
}
