import { useState } from "react";
import { useParams } from "react-router-dom";
import { ShieldAlert } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StatusBadge } from "@/components/common/StatusBadge";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { usePermissions } from "@/hooks/usePermissions";
import {
  useDiscrepancy,
  useResolveDiscrepancy,
  useRequestReupload,
} from "@/features/discrepancies/useDiscrepancies";
import { severityTone } from "@/lib/formatters";

export default function DiscrepancyDetailPage() {
  const { discrepancyId } = useParams<{ discrepancyId: string }>();
  const { data: discrepancy, isLoading, isError, error, refetch } = useDiscrepancy(discrepancyId);
  const resolveMutation = useResolveDiscrepancy(discrepancyId ?? "");
  const reuploadMutation = useRequestReupload(discrepancyId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);

  if (isLoading) return <LoadingState label="Loading discrepancy" />;
  if (isError || !discrepancy) return <ErrorState error={error} onRetry={() => refetch()} />;

  return (
    <>
      <PageHeader
        title={discrepancy.type}
        breadcrumbs={[
          { label: "Discrepancies", to: "/discrepancies" },
          { label: discrepancy.type },
        ]}
        actions={
          <StatusBadge status={discrepancy.severity} tone={severityTone(discrepancy.severity)} />
        }
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Details</h2>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p className="text-slate-600 dark:text-slate-400">{discrepancy.description}</p>
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                reuploadMutation.mutate("Please re-upload a clearer copy of the document.")
              }
              isLoading={reuploadMutation.isPending}
            >
              Request re-upload
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Resolution</h2>
          </CardHeader>
          <CardContent>
            <div className="mb-3 flex items-start gap-2 rounded-md bg-amber-50 p-3 text-xs text-status-warning dark:bg-amber-950">
              <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
              Closing or granting an exception for this discrepancy requires authorized HR approval
              and is recorded in the audit log.
            </div>
            {hasPermission("discrepancy.resolve") && discrepancy.status !== "CLOSED" ? (
              <Button onClick={() => setConfirmOpen(true)}>Resolve / grant exception</Button>
            ) : (
              <p className="text-sm text-slate-500">
                {discrepancy.status === "CLOSED"
                  ? "Already resolved."
                  : "You do not have approval permission for this action."}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Resolve discrepancy"
        description="Confirm resolution or exception for this discrepancy. This decision is final and audited."
        confirmLabel="Resolve"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          await resolveMutation.mutateAsync("approved");
          setConfirmOpen(false);
        }}
      />
    </>
  );
}
