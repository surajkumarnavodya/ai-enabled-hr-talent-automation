import { Link } from "react-router-dom";
import {
  ClipboardList,
  UserSearch,
  CalendarClock,
  MessageSquareWarning,
  CheckSquare,
  FileSignature,
  FileCheck2,
  AlertTriangle,
  UserCheck,
  BellRing,
  CheckCircle2,
  ArrowRight,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { cn } from "@/lib/cn";
import { formatRelative } from "@/lib/dateUtils";
import {
  useDashboardSummary,
  type DashboardSummary,
} from "@/features/dashboard/useDashboardSummary";
import { usePendingApprovals } from "@/features/approvals/useApprovals";

type MetricTone = "neutral" | "warning" | "danger";

interface MetricTile {
  key: keyof DashboardSummary;
  label: string;
  icon: LucideIcon;
  /** Tone applied only when the count is > 0 — a metric that's currently at
   * zero reads as calm/resolved, never a permanently red box (see design
   * audit "color as signal, not decoration"). */
  toneWhenPositive: MetricTone;
}

// Tiles a user needs to act on or should worry about — always shown first.
const ATTENTION_TILES: MetricTile[] = [
  {
    key: "high_severity_discrepancies",
    label: "High-severity discrepancies",
    icon: AlertTriangle,
    toneWhenPositive: "danger",
  },
  {
    key: "sla_breaches",
    label: "Workflow alerts & SLA breaches",
    icon: BellRing,
    toneWhenPositive: "danger",
  },
  {
    key: "pending_approvals",
    label: "Pending approvals",
    icon: CheckSquare,
    toneWhenPositive: "warning",
  },
  {
    key: "pending_interview_feedback",
    label: "Pending interview feedback",
    icon: MessageSquareWarning,
    toneWhenPositive: "warning",
  },
];

// Informational pipeline volume — useful context, not urgent.
const PIPELINE_TILES: MetricTile[] = [
  { key: "active_tans", label: "Active TANs", icon: ClipboardList, toneWhenPositive: "neutral" },
  {
    key: "candidates_awaiting_review",
    label: "Candidates awaiting review",
    icon: UserSearch,
    toneWhenPositive: "neutral",
  },
  {
    key: "interviews_scheduled_today",
    label: "Interviews scheduled today",
    icon: CalendarClock,
    toneWhenPositive: "neutral",
  },
  {
    key: "offers_pending_acceptance",
    label: "Offers pending acceptance",
    icon: FileSignature,
    toneWhenPositive: "neutral",
  },
  {
    key: "green_forms_pending",
    label: "Green Forms pending completion",
    icon: FileCheck2,
    toneWhenPositive: "neutral",
  },
  {
    key: "employee_conversions_pending",
    label: "Employee conversions pending",
    icon: UserCheck,
    toneWhenPositive: "neutral",
  },
];

const ICON_WRAP_CLASSES: Record<MetricTone, string> = {
  neutral: "bg-brand-50 text-brand-600 dark:bg-brand-950",
  warning: "bg-status-warning-tint text-status-warning dark:bg-status-warning-tint-dark",
  danger: "bg-status-danger-tint text-status-danger dark:bg-status-danger-tint-dark",
};

const METRIC_TEXT_CLASSES: Record<MetricTone, string> = {
  neutral: "text-primary",
  warning: "text-status-warning",
  danger: "text-status-danger",
};

function MetricCard({ tile, value }: { tile: MetricTile; value: number }) {
  const resolved = value > 0;
  const tone: MetricTone = resolved ? tile.toneWhenPositive : "neutral";
  const Icon = resolved || tile.toneWhenPositive === "neutral" ? tile.icon : CheckCircle2;

  return (
    <Card>
      <CardContent className="flex items-center gap-4">
        <div className={cn("rounded-md p-2", ICON_WRAP_CLASSES[tone])}>
          <Icon className="h-5 w-5" aria-hidden="true" />
        </div>
        <div className="min-w-0">
          <p className={cn("text-metric", METRIC_TEXT_CLASSES[tone])}>{value}</p>
          <p className="text-xs text-secondary">{tile.label}</p>
        </div>
      </CardContent>
    </Card>
  );
}

function PendingApprovalsPanel() {
  const { data, isLoading, isError, error, refetch } = usePendingApprovals();
  const items = data?.items ?? [];

  return (
    <Card elevation="raised">
      <CardHeader className="flex items-center justify-between">
        <h2 className="text-section-title text-primary">Needs your decision</h2>
        <Link
          to="/approvals"
          className="flex items-center gap-1 text-xs font-medium text-brand-600 transition-colors duration-150 hover:text-brand-700"
        >
          View all
          <ArrowRight className="h-3 w-3" aria-hidden="true" />
        </Link>
      </CardHeader>
      <CardContent className="p-0">
        {isLoading && (
          <div className="p-4">
            <LoadingState label="Loading pending approvals" rows={3} />
          </div>
        )}
        {isError && (
          <div className="p-4">
            <ErrorState error={error} onRetry={() => refetch()} />
          </div>
        )}
        {!isLoading && !isError && items.length === 0 && (
          <div className="p-4">
            <EmptyState
              title="Nothing waiting on you"
              description="New approval requests will show up here as they're submitted."
            />
          </div>
        )}
        {!isLoading && !isError && items.length > 0 && (
          <ul className="divide-y divide-subtle">
            {items.slice(0, 5).map((item) => (
              <li key={item.id}>
                <Link
                  to="/approvals"
                  className="flex items-center justify-between gap-3 px-4 py-3 text-sm transition-colors duration-150 hover:bg-surface-sunken"
                >
                  <span className="min-w-0">
                    <span className="block truncate font-medium text-primary">
                      {item.subject_label}
                    </span>
                    <span className="text-xs text-tertiary">
                      {item.action} · {item.subject_type}
                    </span>
                  </span>
                  <span className="shrink-0 text-xs text-tertiary">
                    {formatRelative(item.requested_at)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const { data, isLoading, isError, error, refetch } = useDashboardSummary();

  return (
    <>
      <PageHeader
        title="Dashboard"
        description="Cross-workflow snapshot of everything needing attention."
      />

      {isLoading && <LoadingState label="Loading dashboard" rows={4} />}
      {isError && <ErrorState error={error} onRetry={() => refetch()} />}

      {data && (
        <div className="space-y-6">
          <section>
            <h2 className="mb-3 text-section-title text-primary">Needs attention</h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {ATTENTION_TILES.map((tile) => (
                <MetricCard key={tile.key} tile={tile} value={data[tile.key]} />
              ))}
            </div>
          </section>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <section className="lg:col-span-2">
              <h2 className="mb-3 text-section-title text-primary">Pipeline overview</h2>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
                {PIPELINE_TILES.map((tile) => (
                  <MetricCard key={tile.key} tile={tile} value={data[tile.key]} />
                ))}
              </div>
            </section>

            <section>
              <h2 className="mb-3 text-section-title text-primary">Approvals</h2>
              <PendingApprovalsPanel />
            </section>
          </div>
        </div>
      )}
    </>
  );
}
