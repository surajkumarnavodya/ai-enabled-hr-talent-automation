import type { DiscrepancySeverity } from "@/types/workflow";
import type { StatusTone } from "@/types/ui";

export function formatPercent(value: number): string {
  return `${Math.round(value)}%`;
}

export function initials(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

const SEVERITY_TONE: Record<DiscrepancySeverity, StatusTone> = {
  low: "info",
  medium: "warning",
  high: "warning",
  critical: "danger",
};

export function severityTone(severity: DiscrepancySeverity): StatusTone {
  return SEVERITY_TONE[severity];
}

export function humanizeStatus(status: string): string {
  return status
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}
