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
        "w-full max-w-md rounded-lg border border-slate-200 bg-white p-0 shadow-lg backdrop:bg-slate-900/40",
        "dark:border-slate-800 dark:bg-slate-900",
        className
      )}
    >
      <div className="flex items-start justify-between border-b border-slate-100 p-4 dark:border-slate-800">
        <div>
          <h2
            id="dialog-title"
            className="text-base font-semibold text-slate-900 dark:text-slate-50"
          >
            {title}
          </h2>
          {description && (
            <p id="dialog-description" className="mt-1 text-sm text-slate-600 dark:text-slate-400">
              {description}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close dialog"
          className="rounded-md p-1 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800"
        >
          <X className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>
      <div className="p-4">{children}</div>
    </dialog>
  );
}
