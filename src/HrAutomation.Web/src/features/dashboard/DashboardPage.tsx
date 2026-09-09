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
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent } from "@/components/ui/Card";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import {
  useDashboardSummary,
  type DashboardSummary,
} from "@/features/dashboard/useDashboardSummary";

interface MetricTile {
  key: keyof DashboardSummary;
  label: string;
  icon: LucideIcon;
  tone: "neutral" | "warning" | "danger";
}

const TILES: MetricTile[] = [
  { key: "active_tans", label: "Active TANs", icon: ClipboardList, tone: "neutral" },
  {
    key: "candidates_awaiting_review",
    label: "Candidates awaiting review",
    icon: UserSearch,
    tone: "neutral",
  },
  {
    key: "interviews_scheduled_today",
    label: "Interviews scheduled today",
    icon: CalendarClock,
    tone: "neutral",
  },
  {
    key: "pending_interview_feedback",
    label: "Pending interview feedback",
    icon: MessageSquareWarning,
    tone: "warning",
  },
  { key: "pending_approvals", label: "Pending approvals", icon: CheckSquare, tone: "warning" },
  {
    key: "offers_pending_acceptance",
    label: "Offers pending acceptance",
    icon: FileSignature,
    tone: "neutral",
  },
  {
    key: "green_forms_pending",
    label: "Green Forms pending completion",
    icon: FileCheck2,
    tone: "neutral",
  },
  {
    key: "high_severity_discrepancies",
    label: "High-severity discrepancies",
    icon: AlertTriangle,
    tone: "danger",
  },
  {
    key: "employee_conversions_pending",
    label: "Employee conversions pending",
    icon: UserCheck,
    tone: "neutral",
  },
  { key: "sla_breaches", label: "Workflow alerts & SLA breaches", icon: BellRing, tone: "danger" },
];

const TONE_CLASSES: Record<MetricTile["tone"], string> = {
  neutral: "text-brand-600 bg-brand-50 dark:bg-brand-950",
  warning: "text-status-warning bg-amber-50 dark:bg-amber-950",
  danger: "text-status-danger bg-red-50 dark:bg-red-950",
};

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
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {TILES.map((tile) => {
            const Icon = tile.icon;
            return (
              <Card key={tile.key}>
                <CardContent className="flex items-center gap-4">
                  <div className={`rounded-md p-2 ${TONE_CLASSES[tile.tone]}`}>
                    <Icon className="h-5 w-5" aria-hidden="true" />
                  </div>
                  <div>
                    <p className="text-2xl font-semibold text-slate-900 dark:text-slate-50">
                      {data[tile.key]}
                    </p>
                    <p className="text-xs text-slate-500 dark:text-slate-400">{tile.label}</p>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
