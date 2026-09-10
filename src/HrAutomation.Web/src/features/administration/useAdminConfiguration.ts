import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { http } from "@/api/client/apiClient";
import { QUERY_KEYS } from "@/lib/constants";

/** Mirrors HrAutomation.Application.Contracts.AdminConfigurationDtos exactly. */
export interface TenantProfile {
  tenant_id: string;
  tenant_code: string;
  tenant_name: string;
  legal_name: string | null;
  primary_domain: string | null;
  row_version: string;
}

export interface NumberingRule {
  numbering_rule_id: string;
  entity_type: string;
  prefix: string | null;
  suffix: string | null;
  number_format: string;
  padding_width: number;
  reset_policy: string;
  current_sequence: number;
  is_active: boolean;
  next_preview: string;
  row_version: string;
}

export interface ApprovalMatrixRule {
  approval_matrix_rule_id: string;
  step_order: number;
  approver_role_id: string | null;
  approver_role_name: string | null;
  is_mandatory: boolean;
  condition_expression: string | null;
  row_version: string;
}

export interface ApprovalMatrix {
  approval_matrix_id: string;
  matrix_code: string;
  matrix_name: string;
  entity_type: string;
  is_active: boolean;
  rules: ApprovalMatrixRule[];
}

export interface RoleOption {
  role_id: string;
  role_name: string;
}

export interface WorkflowState {
  workflow_state_definition_id: string;
  state_code: string;
  state_name: string;
  is_initial_state: boolean;
  is_terminal_state: boolean;
  requires_approval: boolean;
  sort_order: number;
}

export interface WorkflowTransition {
  workflow_transition_definition_id: string;
  from_state_id: string;
  to_state_id: string;
  transition_code: string;
  requires_approval: boolean;
}

export interface WorkflowDefinition {
  workflow_definition_id: string;
  workflow_code: string;
  workflow_name: string;
  description: string | null;
  entity_type: string;
  states: WorkflowState[];
  transitions: WorkflowTransition[];
}

export interface AdminOperationResult {
  success: boolean;
  message: string | null;
  entity_id: string | null;
  error_code: string | null;
}

const CONFIG_KEY = [QUERY_KEYS.admin, "configuration"];

export function useTenantProfile() {
  return useQuery({
    queryKey: [...CONFIG_KEY, "tenant-profile"],
    queryFn: () => http.get<TenantProfile>("/v1/admin/tenant-profile"),
  });
}

export function useUpdateTenantProfile() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: { tenant_name: string; legal_name: string | null; primary_domain: string | null; row_version: string }) =>
      http.patch<AdminOperationResult>("/v1/admin/tenant-profile", body),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: CONFIG_KEY }),
  });
}

export function useNumberingRules() {
  return useQuery({
    queryKey: [...CONFIG_KEY, "numbering-rules"],
    queryFn: () => http.get<NumberingRule[]>("/v1/admin/numbering-rules"),
  });
}

export function useUpdateNumberingRule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      numberingRuleId,
      ...body
    }: {
      numberingRuleId: string;
      prefix: string | null;
      suffix: string | null;
      padding_width: number;
      row_version: string;
    }) => http.patch<AdminOperationResult>(`/v1/admin/numbering-rules/${numberingRuleId}`, body),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: CONFIG_KEY }),
  });
}

export function useApprovalMatrices() {
  return useQuery({
    queryKey: [...CONFIG_KEY, "approval-matrices"],
    queryFn: () => http.get<ApprovalMatrix[]>("/v1/admin/approval-matrices"),
  });
}

export function useApproverRoleOptions() {
  return useQuery({
    queryKey: [...CONFIG_KEY, "approver-roles"],
    queryFn: () => http.get<RoleOption[]>("/v1/admin/approval-matrices/roles"),
  });
}

export function useAddApprovalMatrixRule(matrixId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: {
      step_order: number;
      approver_role_id: string | null;
      is_mandatory: boolean;
      condition_expression: string | null;
    }) => http.post<AdminOperationResult>(`/v1/admin/approval-matrices/${matrixId}/rules`, body),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: CONFIG_KEY }),
  });
}

export function useUpdateApprovalMatrixRule(matrixId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      ruleId,
      ...body
    }: {
      ruleId: string;
      step_order: number;
      approver_role_id: string | null;
      is_mandatory: boolean;
      condition_expression: string | null;
      row_version: string;
    }) => http.patch<AdminOperationResult>(`/v1/admin/approval-matrices/${matrixId}/rules/${ruleId}`, body),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: CONFIG_KEY }),
  });
}

export function useDeleteApprovalMatrixRule(matrixId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (ruleId: string) =>
      http.delete<AdminOperationResult>(`/v1/admin/approval-matrices/${matrixId}/rules/${ruleId}`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: CONFIG_KEY }),
  });
}

export function useWorkflowDefinitions() {
  return useQuery({
    queryKey: [...CONFIG_KEY, "workflow-definitions"],
    queryFn: () => http.get<WorkflowDefinition[]>("/v1/admin/workflow-definitions"),
  });
}
