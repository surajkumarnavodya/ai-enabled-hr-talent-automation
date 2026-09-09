import { CheckCircle2, AlertTriangle, XCircle, Info, Clock, Circle } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import type { StatusTone } from "@/types/ui";
import { humanizeStatus } from "@/lib/formatters";

const TONE_ICON: Record<StatusTone, typeof CheckCircle2> = {
  success: CheckCircle2,
  warning: AlertTriangle,
  danger: XCircle,
  info: Info,
  pending: Clock,
  neutral: Circle,
};

export interface StatusBadgeProps {
  status: string;
  tone: StatusTone;
  /** Override the auto-humanized label derived from `status`. */
  label?: string;
}

/**
 * Status is always communicated via icon + text + color together — never
 * color alone (accessibility requirement, see docs/09-quality-evaluation/frontend-test-strategy.md).
 */
export function StatusBadge({ status, tone, label }: StatusBadgeProps) {
  const Icon = TONE_ICON[tone];
  return (
    <Badge tone={tone}>
      <Icon className="h-3.5 w-3.5" aria-hidden="true" />
      {label ?? humanizeStatus(status)}
    </Badge>
  );
}
