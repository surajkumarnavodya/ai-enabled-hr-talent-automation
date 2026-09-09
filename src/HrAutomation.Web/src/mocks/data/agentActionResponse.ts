import type { AgentActionResponse } from "@/types/api";

/** Builds a plausible AgentActionResponse envelope for MSW handlers — test/demo-mode
 * only. Shaped to match HrAutomation.Application.Contracts.AgentActionResponse exactly
 * so mock and real responses are structurally interchangeable in tests. */
export function mockAgentActionResponse(
  overrides: Partial<AgentActionResponse> & Pick<AgentActionResponse, "action" | "current_state">
): AgentActionResponse {
  return {
    request_id: `mock-req-${Date.now()}`,
    trace_id: `mock-trace-${Date.now()}`,
    tenant_id: "mock-tenant-demo",
    workflow_id: "mock-workflow",
    tan_id: null,
    candidate_id: null,
    application_id: null,
    action_status: "completed",
    proposed_next_state: null,
    data_updated: [],
    explanation: { summary: "Demo response.", job_related_evidence: [], policy_sources: [], confidence: 1 },
    required_approvals: [],
    guardrail_results: {
      authorization: "pass",
      pii_check: "pass",
      prompt_injection_check: "pass",
      policy_check: "pass",
      schema_validation: "pass",
      all_pass: true,
    },
    risks_or_exceptions: [],
    next_allowed_actions: [],
    audit_event: {
      event_type: overrides.action,
      timestamp_utc: new Date().toISOString(),
      actor_type: "AiAgent",
      actor_id: "mock-skill",
    },
    ...overrides,
  };
}
