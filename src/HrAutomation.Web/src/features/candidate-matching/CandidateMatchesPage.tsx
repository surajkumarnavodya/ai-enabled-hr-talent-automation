import { useState } from "react";
import { useParams } from "react-router-dom";
import { CheckCircle2, XCircle, AlertTriangle } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { AiRecommendationPanel } from "@/components/common/AiRecommendationPanel";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { Button } from "@/components/ui/Button";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { usePermissions } from "@/hooks/usePermissions";
import { useMatchResults, useApproveShortlist } from "@/features/candidate-matching/useMatching";
import type { MatchResult } from "@/types/workflow";

export default function CandidateMatchesPage() {
  const { tanId } = useParams<{ tanId: string }>();
  const { data, isLoading, isError, error, refetch } = useMatchResults(tanId);
  const approveShortlist = useApproveShortlist(tanId ?? "");
  const { hasPermission } = usePermissions();
  const [pendingCandidate, setPendingCandidate] = useState<MatchResult | null>(null);

  return (
    <>
      <PageHeader
        title="Candidate Matching"
        breadcrumbs={[
          { label: "TANs", to: "/tans" },
          { label: tanId ?? "", to: `/tans/${tanId}` },
          { label: "Matches" },
        ]}
        description="Ranked, explainable AI recommendations against this TAN's approved JD."
      />

      {isLoading && <LoadingState label="Loading recommendations" />}
      {isError && <ErrorState error={error} onRetry={() => refetch()} />}
      {data && data.length === 0 && (
        <EmptyState
          title="No qualifying candidates found"
          description="Consider broadening the JD criteria."
        />
      )}

      {data && data.length > 0 && (
        <AiRecommendationPanel>
          <div className="space-y-4">
            {data.map((match) => (
              <div
                key={match.applicationId}
                className="rounded-lg border border-subtle bg-surface-raised p-4"
              >
                <div className="mb-3 flex items-center justify-between">
                  <div>
                    <p className="font-medium text-primary">
                      {match.candidateName}
                    </p>
                    <p className="text-xs text-secondary">Model {match.modelVersion}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-2xl font-semibold text-brand-700 dark:text-brand-400">
                      {match.score}
                    </p>
                    <p className="text-xs text-tertiary">match score</p>
                  </div>
                </div>

                <dl className="grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
                  <div>
                    <dt className="mb-1 flex items-center gap-1 font-medium text-status-success">
                      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" /> Matched mandatory
                    </dt>
                    <dd className="text-secondary">
                      {match.matchedMandatory.join(", ") || "—"}
                    </dd>
                  </div>
                  <div>
                    <dt className="mb-1 flex items-center gap-1 font-medium text-status-danger">
                      <XCircle className="h-3.5 w-3.5" aria-hidden="true" /> Missing mandatory
                    </dt>
                    <dd className="text-secondary">
                      {match.missingMandatory.join(", ") || "None"}
                    </dd>
                  </div>
                  <div>
                    <dt className="mb-1 font-medium text-secondary">
                      Preferred matches
                    </dt>
                    <dd className="text-secondary">
                      {match.matchedPreferred.join(", ") || "—"}
                    </dd>
                  </div>
                  <div>
                    <dt className="mb-1 flex items-center gap-1 font-medium text-status-warning">
                      <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" /> Risks /
                      incomplete data
                    </dt>
                    <dd className="text-secondary">
                      {match.risks.join(", ") || "None noted"}
                    </dd>
                  </div>
                </dl>
                <p className="mt-3 text-xs italic text-secondary">
                  {match.evidenceSummary}
                </p>

                {hasPermission("shortlist.approve") && (
                  <div className="mt-4 flex justify-end">
                    <Button size="sm" onClick={() => setPendingCandidate(match)}>
                      Approve for shortlist
                    </Button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </AiRecommendationPanel>
      )}

      <ConfirmActionDialog
        open={pendingCandidate !== null}
        title="Approve shortlist"
        description={
          pendingCandidate
            ? `Shortlist ${pendingCandidate.candidateName} for this TAN? This is a human decision recorded against the AI recommendation above.`
            : ""
        }
        confirmLabel="Approve shortlist"
        onCancel={() => setPendingCandidate(null)}
        onConfirm={async () => {
          if (!pendingCandidate) return;
          await approveShortlist.mutateAsync(pendingCandidate.applicationId);
          setPendingCandidate(null);
        }}
      />
    </>
  );
}
