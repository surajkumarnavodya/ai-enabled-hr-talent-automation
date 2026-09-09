import { appConfig } from "@/app/config/appConfig";

/**
 * All date/time rendering funnels through here so the display timezone is
 * consistent and configurable (VITE_DEFAULT_TIMEZONE) rather than scattered
 * `toLocaleString()` calls with implicit browser-timezone behavior.
 */
export function formatDateTime(iso: string, timeZone: string = appConfig.defaultTimeZone): string {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone,
  }).format(new Date(iso));
}

export function formatDate(iso: string, timeZone: string = appConfig.defaultTimeZone): string {
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeZone }).format(new Date(iso));
}

export function formatRelative(iso: string): string {
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diffMinutes = Math.round((then - now) / 60000);
  const formatter = new Intl.RelativeTimeFormat("en-US", { numeric: "auto" });

  const abs = Math.abs(diffMinutes);
  if (abs < 60) return formatter.format(diffMinutes, "minute");
  if (abs < 60 * 24) return formatter.format(Math.round(diffMinutes / 60), "hour");
  return formatter.format(Math.round(diffMinutes / (60 * 24)), "day");
}
