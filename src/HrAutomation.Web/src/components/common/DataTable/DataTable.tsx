import { useMemo, useState } from "react";
import { ChevronUp, ChevronDown, ChevronLeft, ChevronRight, Columns3 } from "lucide-react";
import type { DataTableColumn, PaginationState } from "@/types/ui";
import { LoadingState } from "@/components/common/LoadingState";
import { EmptyState } from "@/components/common/EmptyState";
import { ErrorState } from "@/components/common/ErrorState";
import { cn } from "@/lib/cn";

export interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  rows: T[];
  getRowId: (row: T) => string;
  isLoading?: boolean;
  isError?: boolean;
  /** The raw query error (from TanStack Query's `error`) — preferred over `errorMessage`, drives user-safe copy and whether Retry is shown. */
  error?: unknown;
  errorMessage?: string;
  onRetry?: () => void;
  emptyTitle?: string;
  emptyDescription?: string;
  pagination?: PaginationState;
  onPageChange?: (pageIndex: number) => void;
  onRowClick?: (row: T) => void;
}

/**
 * Generic, accessible data table: sorting, column visibility, and pagination
 * controls. Sorting/column-visibility are client-side UI concerns; pagination
 * is controlled by the caller (server-side pagination via TanStack Query in
 * real usage) — this component never fetches data itself. When `pagination`
 * is supplied, sorting is scoped to the currently loaded page only — this is
 * called out in the UI rather than left implicit (see design audit "table
 * sort silently operates only on the loaded page").
 */
export function DataTable<T>({
  columns,
  rows,
  getRowId,
  isLoading,
  isError,
  error,
  errorMessage,
  onRetry,
  emptyTitle = "No results",
  emptyDescription = "Try adjusting your filters.",
  pagination,
  onPageChange,
  onRowClick,
}: DataTableProps<T>) {
  const [sortColumnId, setSortColumnId] = useState<string | null>(null);
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("asc");
  const [hiddenColumnIds, setHiddenColumnIds] = useState<Set<string>>(
    () => new Set(columns.filter((c) => c.hiddenByDefault).map((c) => c.id))
  );
  const [showColumnMenu, setShowColumnMenu] = useState(false);

  const visibleColumns = useMemo(
    () => columns.filter((c) => !hiddenColumnIds.has(c.id)),
    [columns, hiddenColumnIds]
  );

  const sortedRows = useMemo(() => {
    if (!sortColumnId) return rows;
    const column = columns.find((c) => c.id === sortColumnId);
    if (!column) return rows;
    const copy = [...rows];
    copy.sort((a, b) => {
      const aText = String(column.accessor(a) ?? "");
      const bText = String(column.accessor(b) ?? "");
      return sortDirection === "asc" ? aText.localeCompare(bText) : bText.localeCompare(aText);
    });
    return copy;
  }, [rows, sortColumnId, sortDirection, columns]);

  function toggleSort(columnId: string) {
    if (sortColumnId !== columnId) {
      setSortColumnId(columnId);
      setSortDirection("asc");
    } else {
      setSortDirection((d) => (d === "asc" ? "desc" : "asc"));
    }
  }

  function toggleColumnVisibility(columnId: string) {
    setHiddenColumnIds((prev) => {
      const next = new Set(prev);
      if (next.has(columnId)) next.delete(columnId);
      else next.add(columnId);
      return next;
    });
  }

  if (isLoading) return <LoadingState rows={5} label="Loading table data" variant="table" />;
  if (isError) return <ErrorState error={error} message={errorMessage} onRetry={onRetry} />;
  if (rows.length === 0) return <EmptyState title={emptyTitle} description={emptyDescription} />;

  const isServerPaginated = Boolean(pagination && pagination.totalCount > rows.length);
  const totalPages = pagination ? Math.max(1, Math.ceil(pagination.totalCount / pagination.pageSize)) : 1;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-2">
        {isServerPaginated && sortColumnId && (
          <p className="text-caption text-tertiary">Sort applies to the current page only.</p>
        )}
        <div className="relative ml-auto">
          <button
            type="button"
            onClick={() => setShowColumnMenu((v) => !v)}
            aria-expanded={showColumnMenu}
            aria-haspopup="true"
            className="flex items-center gap-1.5 rounded-md border border-strong px-2.5 py-1.5 text-xs font-medium text-secondary transition-colors duration-150 hover:bg-surface-sunken"
          >
            <Columns3 className="h-3.5 w-3.5" aria-hidden="true" />
            Columns
          </button>
          {showColumnMenu && (
            <div className="animate-scale-in absolute right-0 z-10 mt-1 w-48 origin-top-right rounded-md border border-subtle bg-surface-raised p-2 shadow-lg">
              {columns.map((col) => (
                <label
                  key={col.id}
                  className="flex items-center gap-2 rounded px-2 py-1.5 text-sm text-secondary hover:bg-surface-sunken"
                >
                  <input
                    type="checkbox"
                    checked={!hiddenColumnIds.has(col.id)}
                    onChange={() => toggleColumnVisibility(col.id)}
                    className="accent-brand-600"
                  />
                  {col.header}
                </label>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="max-h-[65vh] overflow-auto rounded-lg border border-subtle">
        <table className="w-full min-w-[600px] text-sm">
          <thead className="sticky top-0 z-10 bg-surface-sunken">
            <tr>
              {visibleColumns.map((col) => (
                <th
                  key={col.id}
                  scope="col"
                  className={cn(
                    "border-b border-subtle px-4 py-2.5 text-left font-medium text-secondary",
                    col.widthClassName
                  )}
                >
                  {col.sortable ? (
                    <button
                      type="button"
                      onClick={() => toggleSort(col.id)}
                      className="flex items-center gap-1 transition-colors duration-150 hover:text-primary"
                    >
                      {col.header}
                      {sortColumnId === col.id &&
                        (sortDirection === "asc" ? (
                          <ChevronUp className="h-3.5 w-3.5" aria-hidden="true" />
                        ) : (
                          <ChevronDown className="h-3.5 w-3.5" aria-hidden="true" />
                        ))}
                    </button>
                  ) : (
                    col.header
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-subtle">
            {sortedRows.map((row) => (
              <tr
                key={getRowId(row)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  "transition-colors duration-150",
                  onRowClick && "cursor-pointer hover:bg-surface-sunken"
                )}
              >
                {visibleColumns.map((col) => (
                  <td key={col.id} className="px-4 py-2.5 text-secondary">
                    {col.accessor(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pagination && onPageChange && (
        <nav
          aria-label="Table pagination"
          className="mt-3 flex items-center justify-between text-xs text-tertiary"
        >
          <span>
            Page {pagination.pageIndex + 1} of {totalPages} · {pagination.totalCount.toLocaleString()} total
          </span>
          <div className="flex gap-1.5">
            <button
              type="button"
              disabled={pagination.pageIndex === 0}
              onClick={() => onPageChange(pagination.pageIndex - 1)}
              aria-label="Previous page"
              className="flex items-center gap-1 rounded-md border border-strong px-2.5 py-1.5 font-medium text-secondary transition-colors duration-150 hover:bg-surface-sunken disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent"
            >
              <ChevronLeft className="h-3.5 w-3.5" aria-hidden="true" />
              Previous
            </button>
            <button
              type="button"
              disabled={(pagination.pageIndex + 1) * pagination.pageSize >= pagination.totalCount}
              onClick={() => onPageChange(pagination.pageIndex + 1)}
              aria-label="Next page"
              className="flex items-center gap-1 rounded-md border border-strong px-2.5 py-1.5 font-medium text-secondary transition-colors duration-150 hover:bg-surface-sunken disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent"
            >
              Next
              <ChevronRight className="h-3.5 w-3.5" aria-hidden="true" />
            </button>
          </div>
        </nav>
      )}
    </div>
  );
}
