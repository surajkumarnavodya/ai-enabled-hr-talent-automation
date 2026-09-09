import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { StatusBadge } from "@/components/common/StatusBadge";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { useInterview } from "@/features/interviews/useInterviews";
import { formatDateTime } from "@/lib/dateUtils";

export default function InterviewDetailPage() {
  const { interviewId } = useParams<{ interviewId: string }>();
  const { data: interview, isLoading, isError, error, refetch } = useInterview(interviewId);

  if (isLoading) return <LoadingState label="Loading interview" />;
  if (isError || !interview) return <ErrorState error={error} onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title={`${interview.stage} interview — ${interview.candidate_name}`}
        breadcrumbs={[
          { label: "Interviews", to: "/interviews" },
          { label: interview.candidate_name },
        ]}
        actions={
          <ButtonLink to={`/interviews/${interview.interview_round_id}/feedback`} size="sm">
            Submit feedback
          </ButtonLink>
        }
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-primary">Schedule</h2>
          </CardHeader>
          <CardContent className="space-y-2 text-sm">
            <p>
              <span className="text-secondary">Status: </span>
              <StatusBadge status={interview.status} tone="info" />
            </p>
            <p>
              <span className="text-secondary">When: </span>
              {interview.scheduled_at ? formatDateTime(interview.scheduled_at) : "Not yet scheduled"}
            </p>
            <p className="text-xs text-tertiary">
              Reschedule and interviewer-panel selection forms are placeholders in this scaffold.
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-primary">Feedback</h2>
          </CardHeader>
          <CardContent>
            <EmptyState
              variant="restricted"
              title="Feedback visibility is role-restricted"
              description="Only authorized reviewers can see submitted interview feedback, per HrAutomation.Api authorization."
            />
          </CardContent>
        </Card>
      </div>
    </>
  );
}
