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

// Mirrors ref.DiscrepancySeverity.Code exactly (LOW, MEDIUM, HIGH, CRITICAL).
const SEVERITY_TONE: Record<string, StatusTone> = {
  LOW: "info",
  MEDIUM: "warning",
  HIGH: "warning",
  CRITICAL: "danger",
};

export function severityTone(severity: string): StatusTone {
  return SEVERITY_TONE[severity] ?? "neutral";
}

export function humanizeStatus(status: string): string {
  return status
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}
