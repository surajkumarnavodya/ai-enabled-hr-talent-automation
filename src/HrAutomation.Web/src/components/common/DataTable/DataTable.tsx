import { useMemo, useState } from "react";
import { ChevronUp, ChevronDown, Columns3 } from "lucide-react";
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
 * real usage) — this component never fetches data itself.
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

  if (isLoading) return <LoadingState rows={5} label="Loading table data" />;
  if (isError) return <ErrorState error={error} message={errorMessage} onRetry={onRetry} />;
  if (rows.length === 0) return <EmptyState title={emptyTitle} description={emptyDescription} />;

  return (
    <div>
      <div className="mb-2 flex justify-end">
        <div className="relative">
          <button
            type="button"
            onClick={() => setShowColumnMenu((v) => !v)}
            aria-expanded={showColumnMenu}
            aria-haspopup="true"
            className="flex items-center gap-1.5 rounded-md border border-slate-300 px-2.5 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
          >
            <Columns3 className="h-3.5 w-3.5" aria-hidden="true" />
            Columns
          </button>
          {showColumnMenu && (
            <div className="absolute right-0 z-10 mt-1 w-48 rounded-md border border-slate-200 bg-white p-2 shadow-lg dark:border-slate-700 dark:bg-slate-900">
              {columns.map((col) => (
                <label
                  key={col.id}
                  className="flex items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-slate-50 dark:hover:bg-slate-800"
                >
                  <input
                    type="checkbox"
                    checked={!hiddenColumnIds.has(col.id)}
                    onChange={() => toggleColumnVisibility(col.id)}
                  />
                  {col.header}
                </label>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-800">
        <table className="w-full min-w-[600px] text-sm">
          <thead className="bg-slate-50 dark:bg-slate-900">
            <tr>
              {visibleColumns.map((col) => (
                <th
                  key={col.id}
                  scope="col"
                  className={cn(
                    "px-4 py-2.5 text-left font-medium text-slate-600 dark:text-slate-300",
                    col.widthClassName
                  )}
                >
                  {col.sortable ? (
                    <button
                      type="button"
                      onClick={() => toggleSort(col.id)}
                      className="flex items-center gap-1 hover:text-slate-900 dark:hover:text-slate-100"
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
          <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
            {sortedRows.map((row) => (
              <tr
                key={getRowId(row)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  onRowClick && "cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800"
                )}
              >
                {visibleColumns.map((col) => (
                  <td key={col.id} className="px-4 py-2.5 text-slate-700 dark:text-slate-300">
                    {col.accessor(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pagination && onPageChange && (
        <div className="mt-3 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
          <span>
            Showing page {pagination.pageIndex + 1} · {pagination.totalCount.toLocaleString()} total
          </span>
          <div className="flex gap-2">
            <button
              type="button"
              disabled={pagination.pageIndex === 0}
              onClick={() => onPageChange(pagination.pageIndex - 1)}
              className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40 dark:border-slate-700"
            >
              Previous
            </button>
            <button
              type="button"
              disabled={(pagination.pageIndex + 1) * pagination.pageSize >= pagination.totalCount}
              onClick={() => onPageChange(pagination.pageIndex + 1)}
              className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40 dark:border-slate-700"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
