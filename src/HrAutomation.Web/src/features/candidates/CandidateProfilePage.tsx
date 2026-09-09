import { useParams } from "react-router-dom";
import { FileText, ShieldQuestion } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useCandidate } from "@/features/cv-bank/useCandidates";

export default function CandidateProfilePage() {
  const { candidateId } = useParams<{ candidateId: string }>();
  const candidateQuery = useCandidate(candidateId);

  if (candidateQuery.isLoading) return <LoadingState label="Loading candidate" />;
  if (candidateQuery.isError || !candidateQuery.data) {
    return <ErrorState error={candidateQuery.error} onRetry={() => candidateQuery.refetch()} />;
  }

  const candidate = candidateQuery.data;

  return (
    <>
      <PageHeader
        title={candidate.full_name}
        breadcrumbs={[{ label: "CV Bank", to: "/cv-bank" }, { label: candidate.full_name }]}
        actions={
          <StatusBadge
            status={candidate.is_active ? "Active" : "Inactive"}
            tone={candidate.is_active ? "success" : "neutral"}
          />
        }
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <h2 className="text-sm font-semibold text-primary">
              CV documents
            </h2>
          </CardHeader>
          <CardContent>
            {/* Feature not available yet: HrAutomation.Api has no endpoint to list a
                candidate's CV documents separately (see PROJECT_STATUS.md). Showing a
                truthful unavailable state rather than fake document rows. */}
            <EmptyState
              title="CV document list not available yet"
              description="No backend endpoint exists to list this candidate's uploaded CVs individually yet."
              icon={<FileText className="h-8 w-8" />}
            />
            <p className="mt-3 flex items-start gap-1.5 text-xs text-tertiary">
              <ShieldQuestion className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
              Raw document content is rendered only when the API authorizes it for your role.
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <h2 className="text-sm font-semibold text-primary">History</h2>
          </CardHeader>
          <CardContent>
            <EmptyState
              title="No history events yet"
              description="Candidate activity will appear here as applications progress."
            />
          </CardContent>
        </Card>
      </div>
    </>
  );
}
