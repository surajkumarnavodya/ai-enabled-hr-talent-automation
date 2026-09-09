import { useEffect, useRef, type ReactNode } from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/cn";

export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children?: ReactNode;
  className?: string;
}

/**
 * Built on the native <dialog> element for built-in focus trapping, Escape-to-close,
 * and top-layer rendering without pulling in a modal library. Always render actions
 * (confirm/cancel) as children — see ConfirmActionDialog.tsx for the sensitive-action
 * pattern built on top of this.
 */
export function Dialog({ open, onClose, title, description, children, className }: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    if (open && !node.open) node.showModal();
    if (!open && node.open) node.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      aria-labelledby="dialog-title"
      aria-describedby={description ? "dialog-description" : undefined}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClose={onClose}
      className={cn(
        "w-full max-w-md rounded-lg border border-subtle bg-surface-raised p-0 shadow-xl",
        "backdrop:bg-neutral-900/40 open:animate-scale-in",
        className
      )}
    >
      <div className="flex items-start justify-between border-b border-subtle p-4">
        <div>
          <h2 id="dialog-title" className="text-section-title text-primary">
            {title}
          </h2>
          {description && (
            <p id="dialog-description" className="mt-1 text-sm text-secondary">
              {description}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close dialog"
          className="rounded-md p-1 text-secondary transition-colors duration-150 hover:bg-surface-sunken hover:text-primary"
        >
          <X className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>
      <div className="p-4">{children}</div>
    </dialog>
  );
}
