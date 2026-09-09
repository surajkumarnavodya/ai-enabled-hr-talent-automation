import { ALL_ROLES } from "@/lib/constants";
import { Card, CardContent } from "@/components/ui/Card";

/** Read-only view of the fixed role catalog. Role assignment itself happens in the identity provider / HRMS. */
export default function AdminRolesPage() {
  return (
    <Card>
      <CardContent>
        <p className="mb-3 text-sm text-secondary">
          Roles are defined server-side (HrAutomation.Domain.Enums.RoleName) and are not editable
          from this UI.
        </p>
        <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {ALL_ROLES.map((role) => (
            <li
              key={role}
              className="rounded-md border border-subtle px-3 py-2 text-sm text-secondary"
            >
              {role}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
