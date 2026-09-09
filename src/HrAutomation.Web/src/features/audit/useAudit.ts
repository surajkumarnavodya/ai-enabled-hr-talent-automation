import { useQuery } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";
import type { AuditLogEntry } from "@/types/workflow";

export interface AuditFilters {
  entityType?: string;
  tanId?: string;
  candidateId?: string;
  dateFrom?: string;
  action?: string;
  actor?: string;
}

/**
 * Returns exactly what HrAutomation.Api authorizes for the current role —
 * never assume more audit detail exists than what's in the response. See
 * docs/05-security-governance/frontend-security.md.
 */
export function useAuditLog(filters: AuditFilters) {
  return useQuery({
    queryKey: [QUERY_KEYS.audit, filters],
    queryFn: () => http.get<AuditLogEntry[]>("/v1/audit-log", { params: filters }),
  });
}
