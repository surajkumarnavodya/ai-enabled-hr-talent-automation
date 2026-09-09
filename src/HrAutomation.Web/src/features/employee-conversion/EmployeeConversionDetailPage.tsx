import { useState } from "react";
import { useParams } from "react-router-dom";
import { CheckCircle2, XCircle, Clock } from "lucide-react";
import { PageHeader } from "@/components/common/PageHeader";
import { Card, CardContent, CardHeader } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { LoadingState } from "@/components/common/LoadingState";
import { ErrorState } from "@/components/common/ErrorState";
import { ConfirmActionDialog } from "@/components/common/ConfirmActionDialog";
import { usePermissions } from "@/hooks/usePermissions";
import {
  useConversionDetail,
  useConvertToEmployee,
  type ConversionChecklistItem,
} from "@/features/employee-conversion/useEmployeeConversion";
import type { EmployeeCreated } from "@/features/employee-conversion/useEmployeeConversion";

const CHECK_ICON: Record<ConversionChecklistItem["status"], typeof CheckCircle2> = {
  pass: CheckCircle2,
  fail: XCircle,
  pending: Clock,
};
const CHECK_COLOR: Record<ConversionChecklistItem["status"], string> = {
  pass: "text-status-success",
  fail: "text-status-danger",
  pending: "text-status-warning",
};

export default function EmployeeConversionDetailPage() {
  const { applicationId } = useParams<{ applicationId: string }>();
  const { data, isLoading, isError, refetch } = useConversionDetail(applicationId);
  const convertMutation = useConvertToEmployee(applicationId ?? "");
  const { hasPermission } = usePermissions();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [created, setCreated] = useState<EmployeeCreated | null>(null);

  if (isLoading) return <LoadingState label="Loading conversion checklist" />;
  if (isError || !data) return <ErrorState onRetry={() => refetch()} />;

  if (created) {
    return (
      <>
        <PageHeader
          title="Employee created"
          breadcrumbs={[{ label: "Employee Conversion", to: "/employee-conversion" }]}
        />
        <div className="max-w-md rounded-lg border border-emerald-200 bg-emerald-50 p-6 text-center dark:border-emerald-900 dark:bg-emerald-950">
          <CheckCircle2 className="mx-auto mb-3 h-10 w-10 text-status-success" aria-hidden="true" />
          <p className="text-sm text-slate-700 dark:text-slate-300">Employee ID issued:</p>
          <p className="mt-1 text-xl font-semibold text-slate-900 dark:text-slate-50">
            {created.employeeNumber}
          </p>
        </div>
      </>
    );
  }

  const canConvert = hasPermission("employee.convert") && data.eligible;

  return (
    <>
      <PageHeader
        title={`Convert ${data.candidateName}`}
        breadcrumbs={[
          { label: "Employee Conversion", to: "/employee-conversion" },
          { label: data.candidateName },
        ]}
      />

      <Card>
        <CardHeader>
          <h2 className="text-sm font-semibold text-slate-900 dark:text-slate-100">
            Conversion checklist
          </h2>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2">
            {data.checklist.map((item) => {
              const Icon = CHECK_ICON[item.status];
              return (
                <li key={item.check} className="flex items-center gap-2 text-sm">
                  <Icon className={`h-4 w-4 ${CHECK_COLOR[item.status]}`} aria-hidden="true" />
                  {item.check}
                </li>
              );
            })}
          </ul>

          <div className="mt-6">
            <Button disabled={!canConvert} onClick={() => setConfirmOpen(true)}>
              Create Employee ID
            </Button>
            {!canConvert && (
              <p className="mt-2 text-xs text-slate-400">
                Disabled until every checklist item passes and your role is authorized to convert.
              </p>
            )}
          </div>
        </CardContent>
      </Card>

      <ConfirmActionDialog
        open={confirmOpen}
        title="Create Employee ID"
        description={`Convert ${data.candidateName} to an employee and issue an Employee ID? This action is final and audited.`}
        confirmLabel="Create Employee ID"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          const result = await convertMutation.mutateAsync();
          setCreated(result);
          setConfirmOpen(false);
        }}
      />
    </>
  );
}
