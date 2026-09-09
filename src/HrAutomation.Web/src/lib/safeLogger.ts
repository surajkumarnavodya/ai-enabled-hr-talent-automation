/**
 * Centralized, PII-safe logging utility.
 *
 * NON-NEGOTIABLE (see docs/05-security-governance/frontend-security.md and
 * CLAUDE.md): never log PII, raw API responses, documents, candidate data,
 * token values, or sensitive workflow details. This module is the ONLY
 * sanctioned place to call `console.*` in application code — eslint's
 * `no-console` rule enforces that everywhere else.
 *
 * `logEvent` sends structured, redacted diagnostic metadata to an
 * OpenTelemetry-compatible collector when `VITE_OTEL_EXPORTER_OTLP_ENDPOINT`
 * is configured; otherwise (default, including all local dev) it only writes
 * redacted output to the console in non-production builds.
 */
import { appConfig } from "@/app/config/appConfig";

const SENSITIVE_KEY_PATTERN =
  /token|password|secret|ssn|salary|compensation|email|phone|document|cv|feedback|resume/i;

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogFields {
  [key: string]: unknown;
}

/** Recursively strips values under keys that look sensitive, replacing them with "[redacted]". */
export function redact(fields: LogFields, depth = 0): LogFields {
  if (depth > 3) return { note: "[redacted: max depth]" };
  const out: LogFields = {};
  for (const [key, value] of Object.entries(fields)) {
    if (SENSITIVE_KEY_PATTERN.test(key)) {
      out[key] = "[redacted]";
      continue;
    }
    if (value && typeof value === "object" && !Array.isArray(value)) {
      out[key] = redact(value as LogFields, depth + 1);
    } else if (Array.isArray(value)) {
      out[key] = `[array:${value.length}]`;
    } else {
      out[key] = value;
    }
  }
  return out;
}

function emitToConsole(level: LogLevel, message: string, fields?: LogFields): void {
  if (appConfig.env === "prod") return; // no raw console noise in production builds
  const payload = fields ? redact(fields) : undefined;
  // eslint-disable-next-line no-console -- this is the sanctioned logging chokepoint
  console[level === "debug" ? "info" : level](`[hr-web] ${message}`, payload ?? "");
}

function emitToCollector(_level: LogLevel, _message: string, _fields?: LogFields): void {
  if (!appConfig.otelExporterEndpoint) return;
  // TODO: wire an OTLP-compatible exporter (traces/logs) once an OpenTelemetry
  // JS SDK is added to package.json. Intentionally not implemented in this
  // scaffold to avoid bundling telemetry SDK weight before it's configured.
}

export const safeLogger = {
  debug(message: string, fields?: LogFields): void {
    emitToConsole("debug", message, fields);
    emitToCollector("debug", message, fields);
  },
  info(message: string, fields?: LogFields): void {
    emitToConsole("info", message, fields);
    emitToCollector("info", message, fields);
  },
  warn(message: string, fields?: LogFields): void {
    emitToConsole("warn", message, fields);
    emitToCollector("warn", message, fields);
  },
  error(message: string, fields?: LogFields): void {
    emitToConsole("error", message, fields);
    emitToCollector("error", message, fields);
  },
};
