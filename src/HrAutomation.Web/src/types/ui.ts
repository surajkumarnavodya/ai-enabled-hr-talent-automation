import type { ReactNode } from "react";

export type StatusTone = "success" | "warning" | "danger" | "info" | "neutral";

export interface StatusDescriptor {
  label: string;
  tone: StatusTone;
  /** Icon name from lucide-react, resolved by StatusBadge — never color alone. */
  icon?: string;
}

export interface BreadcrumbItem {
  label: string;
  to?: string;
}

export interface DataTableColumn<T> {
  id: string;
  header: string;
  accessor: (row: T) => ReactNode;
  sortable?: boolean;
  /** Hidden by default in the column-selection menu. */
  hiddenByDefault?: boolean;
  widthClassName?: string;
}

export interface PaginationState {
  pageIndex: number;
  pageSize: number;
  totalCount: number;
}

export interface AsyncBoundaryState {
  isLoading: boolean;
  isError: boolean;
  errorMessage?: string;
}
