import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Search } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { DataTable } from "@/components/common/DataTable";
import { Input } from "@/components/ui/Input";
import { ButtonLink } from "@/components/ui/ButtonLink";
import { StatusBadge } from "@/components/common/StatusBadge";
import { useDebounce } from "@/hooks/useDebounce";
import { useCandidateList } from "@/features/cv-bank/useCandidates";
import type { DataTableColumn } from "@/types/ui";
import type { Candidate } from "@/types/workflow";
import { formatDate } from "@/lib/dateUtils";

export default function CvBankListPage() {
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounce(search);
  const navigate = useNavigate();
  // NOTE (API missing): GET /v1/candidates has no server-side search parameter yet -
  // this filters only the current page's already-fetched rows, not the full candidate
  // pool. Do not present this as a real search until the backend supports one.
  const { data, isLoading, isError, error, refetch } = useCandidateList(debouncedSearch);
  const visibleItems = (data?.items ?? []).filter((c) =>
    c.full_name.toLowerCase().includes(debouncedSearch.toLowerCase())
  );

  const columns: DataTableColumn<Candidate>[] = [
    { id: "full_name", header: "Candidate", sortable: true, accessor: (row) => row.full_name },
    { id: "source", header: "Source", accessor: (row) => row.source },
    {
      id: "is_active",
      header: "Status",
      accessor: (row) => (
        <StatusBadge
          status={row.is_active ? "Active" : "Inactive"}
          tone={row.is_active ? "success" : "neutral"}
        />
      ),
    },
    {
      id: "created_at_utc",
      header: "Added",
      sortable: true,
      accessor: (row) => formatDate(row.created_at_utc),
    },
  ];

  return (
    <>
      <PageHeader
        title="Master CV Bank"
        description="Search the candidate pool. Document visibility is limited to what HrAutomation.Api authorizes for your role."
        actions={<ButtonLink to="/cv-bank/upload">Upload CVs</ButtonLink>}
      />

      <div className="mb-4 max-w-sm">
        <label htmlFor="candidate-search" className="sr-only">
          Search candidates
        </label>
        <div className="relative">
          <Search
            className="pointer-events-none absolute left-2.5 top-2.5 h-4 w-4 text-tertiary"
            aria-hidden="true"
          />
          <Input
            id="candidate-search"
            placeholder="Search by name…"
            className="pl-8"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      <DataTable
        columns={columns}
        rows={visibleItems}
        getRowId={(row) => row.candidate_id}
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => refetch()}
        emptyTitle="No candidates found"
        emptyDescription="Try a different search term, or upload a new CV."
        onRowClick={(row) => navigate(`/candidates/${row.candidate_id}`)}
      />
    </>
  );
}
