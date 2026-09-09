import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { StatusBadge } from "@/components/common/StatusBadge";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { useVerificationDetail } from "@/features/verification/useVerification";

export default function VerificationDetailPage() {
  const { applicationId } = useParams<{ applicationId: string }>();
  const { data, isLoading, isError, error, refetch } = useVerificationDetail(applicationId);

  if (isLoading) return <LoadingState label="Loading verification" />;
  if (isError || !data) return <ErrorState error={error} onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title={`Verification — ${data.candidate_name}`}
        breadcrumbs={[
          { label: "Verification", to: "/verification" },
          { label: data.candidate_name },
        ]}
        actions={
          <StatusBadge status={data.status} tone={data.status === "Completed" ? "success" : "warning"} />
        }
      />

      <Card>
        <CardHeader>
          <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Findings</h2>
        </CardHeader>
        <CardContent className="text-sm text-slate-600 dark:text-slate-400">
          <p>
            Detailed field-by-field comparison is provided by HrAutomation.Api and rendered here
            once available.
          </p>
          <div className="mt-4">
            <ButtonLink to="/discrepancies" variant="outline" size="sm">
              View related discrepancies
            </ButtonLink>
          </div>
        </CardContent>
      </Card>
    </>
  );
}
