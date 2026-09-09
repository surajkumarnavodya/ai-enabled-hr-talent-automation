import { dashboardHandlers } from "@/mocks/handlers/dashboard";
import { candidateHandlers } from "@/mocks/handlers/candidates";
import { tanHandlers } from "@/mocks/handlers/tans";
import { applicationHandlers } from "@/mocks/handlers/applications";
import { interviewHandlers } from "@/mocks/handlers/interviews";
import { offerHandlers } from "@/mocks/handlers/offers";
import {
  verificationHandlers,
  discrepancyHandlers,
} from "@/mocks/handlers/verificationAndDiscrepancies";
import { employeeConversionHandlers } from "@/mocks/handlers/employeeConversion";
import { approvalHandlers, auditHandlers } from "@/mocks/handlers/approvalsAndAudit";
import { greenFormHandlers } from "@/mocks/handlers/greenForms";
import { administrationHandlers } from "@/mocks/handlers/administration";

export const handlers = [
  ...dashboardHandlers,
  ...candidateHandlers,
  ...tanHandlers,
  ...applicationHandlers,
  ...interviewHandlers,
  ...offerHandlers,
  ...verificationHandlers,
  ...discrepancyHandlers,
  ...employeeConversionHandlers,
  ...approvalHandlers,
  ...auditHandlers,
  ...greenFormHandlers,
  ...administrationHandlers,
];
