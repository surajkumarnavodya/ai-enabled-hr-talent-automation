import { StatusBadge } from "@/components/common/StatusBadge";
import { Card, CardContent } from "@/components/ui/Card";

// TODO(api-contract): replace with a real integration-health endpoint once available (see mcp/servers/README.md).
const PLACEHOLDER_INTEGRATIONS = [
  { name: "Calendar (mcp-calendar)", status: "unknown" as const },
  { name: "Email (mcp-email)", status: "unknown" as const },
  { name: "HRMS (mcp-hrms)", status: "unknown" as const },
  { name: "E-signature (mcp-esignature)", status: "unknown" as const },
];

export default function AdminIntegrationsPage() {
  return (
    <Card>
      <CardContent>
        <ul className="divide-y divide-subtle">
          {PLACEHOLDER_INTEGRATIONS.map((integration) => (
            <li key={integration.name} className="flex items-center justify-between py-2 text-sm">
              <span className="text-secondary">{integration.name}</span>
              <StatusBadge status={integration.status} tone="neutral" label="Status unknown" />
            </li>
          ))}
        </ul>
        <p className="mt-3 text-xs text-tertiary">
          Live integration health requires the MCP servers described in docs/07-mcp-integrations/ to
          be deployed.
        </p>
      </CardContent>
    </Card>
  );
}
