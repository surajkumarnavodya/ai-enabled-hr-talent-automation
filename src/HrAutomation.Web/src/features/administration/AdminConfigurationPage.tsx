import { useState } from "react";
import { Plus, Pencil, Trash2, ShieldAlert, Info } from "lucide-react";
import { ConfigVersionMeta } from "@/features/administration/ConfigVersionMeta";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Dialog } from "@/components/ui/Dialog";
import { Badge } from "@/components/ui/Badge";
import { StatusBadge } from "@/components/common/StatusBadge";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { FormField } from "@/components/forms/FormField";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { EmptyState } from "@/components/common/EmptyState";
import { PermissionDenied } from "@/components/common/PermissionDenied";
import { useHasPermission } from "@/features/administration/useAdminUsers";
import { useToast } from "@/app/providers/ToastProvider";
import { userSafeMessage } from "@/api/client/apiError";
import { cn } from "@/lib/cn";
import {
  useTenantProfile,
  useUpdateTenantProfile,
  useNumberingRules,
  useUpdateNumberingRule,
  useApprovalMatrices,
  useApproverRoleOptions,
  useAddApprovalMatrixRule,
  useUpdateApprovalMatrixRule,
  useDeleteApprovalMatrixRule,
  useWorkflowDefinitions,
  type NumberingRule,
  type ApprovalMatrix,
  type ApprovalMatrixRule,
} from "@/features/administration/useAdminConfiguration";

// ============================================================================
// Tenant profile
// ============================================================================

function TenantProfileSection() {
  const { loading: permLoading, allowed: canRead } = useHasPermission("tenant.read");
  const { allowed: canManage } = useHasPermission("tenant.manage");
  const { data, isLoading, isError, error, refetch } = useTenantProfile();
  const updateMutation = useUpdateTenantProfile();
  const { showToast } = useToast();
  const [form, setForm] = useState<{ tenant_name: string; legal_name: string; primary_domain: string } | null>(null);

  if (permLoading) return <LoadingState label="Checking permissions" />;
  if (!canRead) {
    return (
      <PermissionDenied message="Viewing tenant settings requires the 'tenant.read' permission, which your current role does not grant." />
    );
  }
  if (isLoading) return <LoadingState label="Loading tenant profile" />;
  if (isError || !data) return <ErrorState error={error} onRetry={() => refetch()} />;

  const editing = form !== null;
  const values = form ?? {
    tenant_name: data.tenant_name,
    legal_name: data.legal_name ?? "",
    primary_domain: data.primary_domain ?? "",
  };

  async function handleSave() {
    if (!form || !data) return;
    try {
      await updateMutation.mutateAsync({
        tenant_name: form.tenant_name,
        legal_name: form.legal_name || null,
        primary_domain: form.primary_domain || null,
        row_version: data.row_version,
      });
      showToast({ title: "Tenant profile updated", tone: "success" });
      setForm(null);
    } catch (err) {
      showToast({ title: "Couldn't save tenant profile", description: userSafeMessage(err), tone: "danger", durationMs: 0 });
    }
  }

  return (
    <Card elevation="raised">
      <CardHeader className="flex items-center justify-between">
        <div>
          <h2 className="text-section-title text-primary">Tenant profile</h2>
          <p className="mt-0.5 text-xs text-tertiary">Code: {data.tenant_code}</p>
        </div>
        {canManage && !editing && (
          <Button size="sm" variant="outline" onClick={() => setForm(values)}>
            <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
            Edit
          </Button>
        )}
      </CardHeader>
      <CardContent>
        {editing ? (
          <div className="max-w-lg space-y-4">
            <FormField label="Tenant name" required>
              <Input
                value={form.tenant_name}
                onChange={(e) => setForm({ ...form, tenant_name: e.target.value })}
              />
            </FormField>
            <FormField label="Legal name" hint="Optional">
              <Input
                value={form.legal_name}
                onChange={(e) => setForm({ ...form, legal_name: e.target.value })}
              />
            </FormField>
            <FormField label="Primary domain" hint="Optional">
              <Input
                value={form.primary_domain}
                onChange={(e) => setForm({ ...form, primary_domain: e.target.value })}
              />
            </FormField>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setForm(null)} disabled={updateMutation.isPending}>
                Cancel
              </Button>
              <Button onClick={handleSave} isLoading={updateMutation.isPending} disabled={!form.tenant_name.trim()}>
                Save
              </Button>
            </div>
          </div>
        ) : (
          <dl className="grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-secondary">Tenant name</dt>
              <dd className="text-primary">{data.tenant_name}</dd>
            </div>
            <div>
              <dt className="text-secondary">Legal name</dt>
              <dd className="text-primary">{data.legal_name ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-secondary">Primary domain</dt>
              <dd className="text-primary">{data.primary_domain ?? "—"}</dd>
            </div>
          </dl>
        )}
      </CardContent>
    </Card>
  );
}

// ============================================================================
// Numbering rules
// ============================================================================

function NumberingRuleEditDialog({
  rule,
  onClose,
}: {
  rule: NumberingRule;
  onClose: () => void;
}) {
  const [prefix, setPrefix] = useState(rule.prefix ?? "");
  const [suffix, setSuffix] = useState(rule.suffix ?? "");
  const [paddingWidth, setPaddingWidth] = useState(rule.padding_width);
  const mutation = useUpdateNumberingRule();
  const { showToast } = useToast();

  async function handleSave() {
    try {
      await mutation.mutateAsync({
        numberingRuleId: rule.numbering_rule_id,
        prefix: prefix || null,
        suffix: suffix || null,
        padding_width: paddingWidth,
        row_version: rule.row_version,
      });
      showToast({ title: `${rule.entity_type} numbering rule updated`, tone: "success" });
      onClose();
    } catch (err) {
      showToast({ title: "Couldn't save numbering rule", description: userSafeMessage(err), tone: "danger", durationMs: 0 });
    }
  }

  return (
    <Dialog
      open
      onClose={onClose}
      title={`Edit ${rule.entity_type} numbering`}
      description="Applies to numbers generated from now on — already-issued numbers are never retroactively changed."
    >
      <div className="space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Prefix" hint="Optional">
            <Input value={prefix} onChange={(e) => setPrefix(e.target.value)} maxLength={20} />
          </FormField>
          <FormField label="Suffix" hint="Optional">
            <Input value={suffix} onChange={(e) => setSuffix(e.target.value)} maxLength={20} />
          </FormField>
        </div>
        <FormField label="Padding width" hint="Number of digits, e.g. 6 → 000123">
          <Input
            type="number"
            min={1}
            max={20}
            value={paddingWidth}
            onChange={(e) => setPaddingWidth(Number(e.target.value))}
          />
        </FormField>
        <p className="text-xs text-tertiary">
          Preview of next number: <span className="font-mono text-secondary">{(prefix || "")}{String(rule.current_sequence + 1).padStart(paddingWidth, "0")}{(suffix || "")}</span>
        </p>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={onClose} disabled={mutation.isPending}>
            Cancel
          </Button>
          <Button onClick={handleSave} isLoading={mutation.isPending} disabled={paddingWidth < 1 || paddingWidth > 20}>
            Save
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function NumberingRulesSection() {
  const { loading: permLoading, allowed: canRead } = useHasPermission("configuration.read");
  const { allowed: canManage } = useHasPermission("configuration.manage");
  const { data, isLoading, isError, error, refetch } = useNumberingRules();
  const [editingRule, setEditingRule] = useState<NumberingRule | null>(null);

  if (permLoading) return <LoadingState label="Checking permissions" />;
  if (!canRead) {
    return (
      <PermissionDenied message="Viewing numbering rules requires the 'configuration.read' permission, which your current role does not grant." />
    );
  }
  if (isLoading) return <LoadingState label="Loading numbering rules" variant="table" />;
  if (isError) return <ErrorState error={error} onRetry={() => refetch()} />;
  if (!data || data.length === 0) {
    return <EmptyState title="No numbering rules configured" description="TAN, offer, and Employee ID numbering have no active rule yet." />;
  }

  return (
    <Card elevation="raised">
      <CardHeader>
        <h2 className="text-section-title text-primary">Document numbering</h2>
        <p className="mt-0.5 text-xs text-tertiary">
          Controls the format of TAN numbers, Employee IDs, and offer numbers — genuinely applied by the
          number-generation procedures, not a display-only setting.
        </p>
      </CardHeader>
      <CardContent className="p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-surface-sunken">
              <tr>
                <th scope="col" className="border-b border-subtle px-4 py-2.5 text-left font-medium text-secondary">Entity</th>
                <th scope="col" className="border-b border-subtle px-4 py-2.5 text-left font-medium text-secondary">Format</th>
                <th scope="col" className="border-b border-subtle px-4 py-2.5 text-left font-medium text-secondary">Next number</th>
                <th scope="col" className="border-b border-subtle px-4 py-2.5 text-left font-medium text-secondary">Status</th>
                {canManage && <th scope="col" className="border-b border-subtle px-4 py-2.5" />}
              </tr>
            </thead>
            <tbody className="divide-y divide-subtle">
              {data.map((rule) => (
                <tr key={rule.numbering_rule_id}>
                  <td className="px-4 py-2.5 font-medium text-primary">{rule.entity_type}</td>
                  <td className="px-4 py-2.5 text-secondary">
                    {(rule.prefix || "").length > 0 || (rule.suffix || "").length > 0 ? (
                      <span className="font-mono">{rule.prefix}{"0".repeat(rule.padding_width)}{rule.suffix}</span>
                    ) : (
                      <span className="font-mono">{"0".repeat(rule.padding_width)}</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 font-mono text-secondary">{rule.next_preview}</td>
                  <td className="px-4 py-2.5">
                    <StatusBadge status={rule.is_active ? "Active" : "Inactive"} tone={rule.is_active ? "success" : "neutral"} />
                  </td>
                  {canManage && (
                    <td className="px-4 py-2.5 text-right">
                      <Button size="sm" variant="ghost" onClick={() => setEditingRule(rule)}>
                        <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
                        Edit
                      </Button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
      {editingRule && <NumberingRuleEditDialog rule={editingRule} onClose={() => setEditingRule(null)} />}
    </Card>
  );
}

// ============================================================================
// Approval matrix
// ============================================================================

interface ApprovalRuleFormState {
  stepOrder: number;
  approverRoleId: string;
  isMandatory: boolean;
  conditionExpression: string;
}

function ApprovalMatrixRuleDialog({
  matrixId,
  rule,
  nextStepOrder,
  roles,
  onClose,
}: {
  matrixId: string;
  rule: ApprovalMatrixRule | null;
  nextStepOrder: number;
  roles: { role_id: string; role_name: string }[];
  onClose: () => void;
}) {
  const isEdit = rule !== null;
  const [form, setForm] = useState<ApprovalRuleFormState>({
    stepOrder: rule?.step_order ?? nextStepOrder,
    approverRoleId: rule?.approver_role_id ?? "",
    isMandatory: rule?.is_mandatory ?? true,
    conditionExpression: rule?.condition_expression ?? "",
  });
  const [confirmOpen, setConfirmOpen] = useState(false);
  const addMutation = useAddApprovalMatrixRule(matrixId);
  const updateMutation = useUpdateApprovalMatrixRule(matrixId);
  const { showToast } = useToast();

  async function handleConfirm() {
    try {
      if (isEdit) {
        await updateMutation.mutateAsync({
          ruleId: rule.approval_matrix_rule_id,
          step_order: form.stepOrder,
          approver_role_id: form.approverRoleId || null,
          is_mandatory: form.isMandatory,
          condition_expression: form.conditionExpression || null,
          row_version: rule.row_version,
        });
        showToast({ title: "Approval step updated", tone: "success" });
      } else {
        await addMutation.mutateAsync({
          step_order: form.stepOrder,
          approver_role_id: form.approverRoleId || null,
          is_mandatory: form.isMandatory,
          condition_expression: form.conditionExpression || null,
        });
        showToast({ title: "Approval step added", tone: "success" });
      }
      setConfirmOpen(false);
      onClose();
    } catch (err) {
      showToast({ title: "Couldn't save approval step", description: userSafeMessage(err), tone: "danger", durationMs: 0 });
      setConfirmOpen(false);
    }
  }

  return (
    <>
      <Dialog open onClose={onClose} title={isEdit ? "Edit approval step" : "Add approval step"}>
        <div className="space-y-4">
          <FormField label="Step order" required hint="Steps are approved in ascending order">
            <Input
              type="number"
              min={1}
              value={form.stepOrder}
              onChange={(e) => setForm({ ...form, stepOrder: Number(e.target.value) })}
            />
          </FormField>
          <FormField
            label="Approver role (label only)"
            hint="Descriptive — actual approver eligibility is enforced by each approval endpoint's own role check, independent of this field."
          >
            <Select
              value={form.approverRoleId}
              onChange={(e) => setForm({ ...form, approverRoleId: e.target.value })}
            >
              <option value="">— none —</option>
              {roles.map((r) => (
                <option key={r.role_id} value={r.role_id}>
                  {r.role_name}
                </option>
              ))}
            </Select>
          </FormField>
          <label className="flex items-center gap-2 text-sm text-secondary">
            <input
              type="checkbox"
              className="accent-brand-600"
              checked={form.isMandatory}
              onChange={(e) => setForm({ ...form, isMandatory: e.target.checked })}
            />
            Mandatory step
          </label>
          <FormField label="Condition" hint="Optional expression describing when this step applies">
            <Input
              value={form.conditionExpression}
              onChange={(e) => setForm({ ...form, conditionExpression: e.target.value })}
            />
          </FormField>
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button onClick={() => setConfirmOpen(true)} disabled={form.stepOrder < 1}>
              {isEdit ? "Save" : "Add step"}
            </Button>
          </div>
        </div>
      </Dialog>

      <ConfirmActionDialog
        open={confirmOpen}
        title={isEdit ? "Confirm approval step change" : "Confirm new approval step"}
        description="This changes how many human approvals a real request against this matrix will require going forward."
        confirmLabel={isEdit ? "Save change" : "Add step"}
        onCancel={() => setConfirmOpen(false)}
        onConfirm={handleConfirm}
      />
    </>
  );
}

function ApprovalMatrixCard({
  matrix,
  canManage,
  roles,
}: {
  matrix: ApprovalMatrix;
  canManage: boolean;
  roles: { role_id: string; role_name: string }[];
}) {
  const [dialogRule, setDialogRule] = useState<ApprovalMatrixRule | "new" | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<ApprovalMatrixRule | null>(null);
  const deleteMutation = useDeleteApprovalMatrixRule(matrix.approval_matrix_id);
  const { showToast } = useToast();
  const sortedRules = [...matrix.rules].sort((a, b) => a.step_order - b.step_order);
  const nextStepOrder = sortedRules.length > 0 ? Math.max(...sortedRules.map((r) => r.step_order)) + 1 : 1;

  async function handleDelete() {
    if (!deleteTarget) return;
    try {
      await deleteMutation.mutateAsync(deleteTarget.approval_matrix_rule_id);
      showToast({ title: "Approval step removed", tone: "success" });
      setDeleteTarget(null);
    } catch (err) {
      showToast({ title: "Couldn't remove approval step", description: userSafeMessage(err), tone: "danger", durationMs: 0 });
      setDeleteTarget(null);
    }
  }

  return (
    <Card>
      <CardHeader className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold text-primary">{matrix.matrix_name}</h3>
          <p className="mt-0.5 font-mono text-xs text-tertiary">{matrix.matrix_code} · {matrix.entity_type}</p>
        </div>
        <div className="flex items-center gap-2">
          <StatusBadge status={matrix.is_active ? "Active" : "Inactive"} tone={matrix.is_active ? "success" : "neutral"} />
          {canManage && (
            <Button size="sm" variant="outline" onClick={() => setDialogRule("new")}>
              <Plus className="h-3.5 w-3.5" aria-hidden="true" />
              Add step
            </Button>
          )}
        </div>
      </CardHeader>
      <CardContent className="p-0">
        {sortedRules.length === 0 ? (
          <div className="p-4">
            <EmptyState
              variant="restricted"
              title="No approval steps configured"
              description="A submission against this matrix currently has no human approval gate."
            />
          </div>
        ) : (
          <ul className="divide-y divide-subtle">
            {sortedRules.map((rule) => (
              <li key={rule.approval_matrix_rule_id} className="flex items-center justify-between gap-3 px-4 py-3 text-sm">
                <div className="flex min-w-0 items-center gap-3">
                  <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-50 text-xs font-semibold text-brand-700 dark:bg-brand-950 dark:text-brand-400">
                    {rule.step_order}
                  </span>
                  <div className="min-w-0">
                    <p className="truncate font-medium text-primary">
                      {rule.approver_role_name ?? "Unassigned role"}
                      {!rule.is_mandatory && <span className="ml-1.5 font-normal text-tertiary">(optional)</span>}
                    </p>
                    {rule.condition_expression && (
                      <p className="truncate text-xs text-tertiary">{rule.condition_expression}</p>
                    )}
                  </div>
                </div>
                {canManage && (
                  <div className="flex shrink-0 gap-1">
                    <Button size="sm" variant="ghost" onClick={() => setDialogRule(rule)} aria-label="Edit step">
                      <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => setDeleteTarget(rule)} aria-label="Remove step">
                      <Trash2 className="h-3.5 w-3.5 text-status-danger" aria-hidden="true" />
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </CardContent>

      {dialogRule && (
        <ApprovalMatrixRuleDialog
          matrixId={matrix.approval_matrix_id}
          rule={dialogRule === "new" ? null : dialogRule}
          nextStepOrder={nextStepOrder}
          roles={roles}
          onClose={() => setDialogRule(null)}
        />
      )}

      <ConfirmActionDialog
        open={deleteTarget !== null}
        title="Remove approval step"
        description={`This permanently removes step ${deleteTarget?.step_order} from this matrix. A matrix must always keep at least one mandatory step — the server will reject this if it's the last one.`}
        confirmLabel="Remove step"
        destructive
        onCancel={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
      />
    </Card>
  );
}

function ApprovalMatrixSection() {
  const { loading: permLoading, allowed: canRead } = useHasPermission("workflow.read");
  const { allowed: canManage } = useHasPermission("workflow.manage");
  const { data, isLoading, isError, error, refetch } = useApprovalMatrices();
  const { data: roles } = useApproverRoleOptions();

  if (permLoading) return <LoadingState label="Checking permissions" />;
  if (!canRead) {
    return (
      <PermissionDenied message="Viewing the approval matrix requires the 'workflow.read' permission, which your current role does not grant." />
    );
  }
  if (isLoading) return <LoadingState label="Loading approval matrices" />;
  if (isError) return <ErrorState error={error} onRetry={() => refetch()} />;
  if (!data || data.length === 0) {
    return <EmptyState title="No approval matrices configured" />;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-2 rounded-md bg-status-info-tint p-3 text-xs text-status-info dark:bg-status-info-tint-dark">
        <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        Changing the number of mandatory steps here genuinely changes how many human approvals a real
        request requires — this is not a documentation-only screen. Every change is audit-logged.
      </div>
      {data.map((matrix) => (
        <ApprovalMatrixCard
          key={matrix.approval_matrix_id}
          matrix={matrix}
          canManage={canManage}
          roles={roles ?? []}
        />
      ))}
    </div>
  );
}

// ============================================================================
// Workflow definitions (read-only reference)
// ============================================================================

function WorkflowDefinitionsSection() {
  const { loading: permLoading, allowed: canRead } = useHasPermission("workflow.read");
  const { data, isLoading, isError, error, refetch } = useWorkflowDefinitions();

  if (permLoading) return <LoadingState label="Checking permissions" />;
  if (!canRead) {
    return (
      <PermissionDenied message="Viewing workflow definitions requires the 'workflow.read' permission, which your current role does not grant." />
    );
  }
  if (isLoading) return <LoadingState label="Loading workflow definitions" />;
  if (isError) return <ErrorState error={error} onRetry={() => refetch()} />;
  if (!data || data.length === 0) {
    return <EmptyState title="No workflow definitions found" />;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-2 rounded-md bg-surface-sunken p-3 text-xs text-secondary">
        <Info className="mt-0.5 h-4 w-4 shrink-0 text-tertiary" aria-hidden="true" />
        Reference documentation only. Each entity's real transitions are enforced by its own stored
        procedure (see ADR-006), not by this table — editing it would have no effect on real behavior,
        so it isn't editable here.
      </div>
      {data.map((wf) => (
        <Card key={wf.workflow_definition_id}>
          <CardHeader>
            <h3 className="text-sm font-semibold text-primary">{wf.workflow_name}</h3>
            <p className="mt-0.5 font-mono text-xs text-tertiary">{wf.workflow_code} · {wf.entity_type}</p>
          </CardHeader>
          <CardContent className="space-y-3">
            {wf.description && <p className="text-sm text-secondary">{wf.description}</p>}
            <div className="flex flex-wrap gap-1.5">
              {wf.states
                .slice()
                .sort((a, b) => a.sort_order - b.sort_order)
                .map((s) => (
                  <Badge key={s.workflow_state_definition_id} tone={s.is_terminal_state ? "neutral" : s.requires_approval ? "warning" : "info"}>
                    {s.state_name}
                  </Badge>
                ))}
            </div>
            <p className="text-xs text-tertiary">{wf.transitions.length} defined transition{wf.transitions.length === 1 ? "" : "s"}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

// ============================================================================
// Page
// ============================================================================

const TABS = [
  { id: "tenant", label: "Tenant profile" },
  { id: "numbering", label: "Document numbering" },
  { id: "approvals", label: "Approval matrix" },
  { id: "workflows", label: "Workflow definitions" },
] as const;

type TabId = (typeof TABS)[number]["id"];

export default function AdminConfigurationPage() {
  const [active, setActive] = useState<TabId>("tenant");

  return (
    <div>
      <ConfigVersionMeta version="1.0.0" effectiveDate="2026-09-07" approvedBy="Demo HR Admin" />

      <div role="tablist" aria-label="Configuration area" className="mb-4 flex flex-wrap gap-1 border-b border-subtle">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={active === tab.id}
            onClick={() => setActive(tab.id)}
            className={cn(
              "border-b-2 px-3 py-2 text-sm font-medium transition-colors duration-150",
              active === tab.id
                ? "border-brand-600 text-brand-700 dark:text-brand-400"
                : "border-transparent text-tertiary hover:text-primary"
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {active === "tenant" && <TenantProfileSection />}
      {active === "numbering" && <NumberingRulesSection />}
      {active === "approvals" && <ApprovalMatrixSection />}
      {active === "workflows" && <WorkflowDefinitionsSection />}
    </div>
  );
}
