import { getFeatureFlags } from "@/app/config/featureFlags";
import { ConfigVersionMeta } from "@/features/administration/ConfigVersionMeta";
import { Card, CardContent } from "@/components/ui/Card";
import { StatusBadge } from "@/components/common/StatusBadge";

export default function AdminFeatureFlagsPage() {
  const flags = getFeatureFlags();

  return (
    <div>
      <ConfigVersionMeta version="1.0.0" effectiveDate="2026-09-07" approvedBy="Demo HR Admin" />
      <Card>
        <CardContent>
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {Object.entries(flags).map(([key, value]) => (
              <li key={key} className="flex items-center justify-between py-2 text-sm">
                <span className="font-mono text-slate-700 dark:text-slate-300">{key}</span>
                <StatusBadge
                  status={value ? "enabled" : "disabled"}
                  tone={value ? "success" : "neutral"}
                />
              </li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-slate-400">
            Read-only in this scaffold. See config/feature-flags/ at the repository root for the
            target admin-configurable model.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
