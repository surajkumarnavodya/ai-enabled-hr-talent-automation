import { useState } from "react";
import { ShieldAlert } from "lucide-react";
import { Dialog } from "@/components/ui/Dialog";
import { Button } from "@/components/ui/Button";

export interface ConfirmActionDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  /** e.g. "This will call HrAutomation.Api and requires your recorded approval." */
  serverApprovalNotice?: string;
  destructive?: boolean;
  onConfirm: () => void | Promise<void>;
  onCancel: () => void;
}

/**
 * Mandatory confirmation gate for every sensitive workflow action (shortlist
 * approval, offer send, discrepancy resolution, employee conversion, etc.).
 * Confirming here only triggers the API call — the backend remains the sole
 * authority on whether the action is actually permitted. See CLAUDE.md
 * "Sensitive actions must display an explicit confirmation dialog".
 *
 * Prevents duplicate submission via an internal isSubmitting guard in
 * addition to the caller's own mutation-pending state.
 */
export function ConfirmActionDialog({
  open,
  title,
  description,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  serverApprovalNotice = "This action is recorded and enforced by HrAutomation.Api — the UI does not make the final decision.",
  destructive = false,
  onConfirm,
  onCancel,
}: ConfirmActionDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleConfirm() {
    if (isSubmitting) return;
    setIsSubmitting(true);
    try {
      await onConfirm();
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onClose={onCancel} title={title} description={description}>
      <div className="flex items-start gap-2 rounded-md bg-surface-sunken p-3 text-xs text-secondary">
        <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" aria-hidden="true" />
        <span>{serverApprovalNotice}</span>
      </div>
      <div className="mt-4 flex justify-end gap-2">
        <Button variant="outline" onClick={onCancel} disabled={isSubmitting}>
          {cancelLabel}
        </Button>
        <Button
          variant={destructive ? "danger" : "primary"}
          onClick={handleConfirm}
          isLoading={isSubmitting}
        >
          {confirmLabel}
        </Button>
      </div>
    </Dialog>
  );
}
