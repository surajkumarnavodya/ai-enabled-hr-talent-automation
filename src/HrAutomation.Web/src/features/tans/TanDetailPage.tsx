import { useState } from "react";
import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { StatusBadge } from "@/components/common/StatusBadge";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { AuditTimeline } from "@/components/common/AuditTimeline";
import { usePermissions } from "@/hooks/usePermissions";
import { useTan, useApproveTan } from "@/features/tans/useTans";

/** Mirrors recruitment.JobRequisition.RequisitionStatusCode's real values exactly. */
const TAN_STATUS_TONE: Record<string, "neutral" | "info" | "success" | "warning"> = {
  Draft: "neutral",
  PendingApproval: "warning",
  Approved: "success",
  ActiveSourcing: "info",
  OnHold: "warning",
  ClosedFilled: "neutral",
  Cancelled: "neutral",
};

export default function TanDetailPage() {
  const { tanId } = useParams<{ tanId: string }>();
  const { data: tan, isLoading, isError, error, refetch } = useTan(tanId);
  const approveTan = useApproveTan(tanId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (isLoading) return <LoadingState label="Loading TAN" />;
  if (isError || !tan) return <ErrorState error={error} onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title={tan.title}
        breadcrumbs={[{ label: "TANs", to: "/tans" }, { label: tan.tan_number }]}
        actions={
          <>
            <StatusBadge status={tan.status} tone={TAN_STATUS_TONE[tan.status] ?? "neutral"} />
            <ButtonLink to={`/tans/${tan.tan_id}/edit`} variant="outline" size="sm">
              Edit
            </ButtonLink>
            {hasPermission("tan.approve") && tan.status === "PendingApproval" && (
              <Button size="sm" onClick={() => setConfirmOpen(true)}>
                Approve TAN
              </Button>
            )}
          </>
        }
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Candidate pipeline
            </h2>
          </CardHeader>
          <CardContent>
            <EmptyState
              title="No candidates in the pipeline yet"
              description="Run AI matching once this TAN is approved."
              action={
                <ButtonLink to={`/tans/${tan.tan_id}/matches`} variant="outline" size="sm">
                  View matches
                </ButtonLink>
              }
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Audit timeline
            </h2>
          </CardHeader>
          <CardContent>
            <AuditTimeline entries={[]} />
          </CardContent>
        </Card>
      </div>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Approve TAN"
        description={`Approve ${tan.tan_number} — ${tan.title}? This unlocks AI candidate matching.`}
        confirmLabel="Approve"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          await approveTan.mutateAsync({ decision: "Approved" });
          setConfirmOpen(false);
        }}
      />
    </>
  );
}
