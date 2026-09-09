import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from "react";
import { CheckCircle2, XCircle, Info, X } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";

export type ToastTone = "success" | "danger" | "info";

export interface ToastInput {
  title: string;
  description?: string;
  tone?: ToastTone;
  /** ms before auto-dismiss; 0 disables auto-dismiss (use for errors the user should consciously acknowledge). */
  durationMs?: number;
}

interface ToastItem extends Required<Omit<ToastInput, "durationMs">> {
  id: number;
  durationMs: number;
}

interface ToastContextValue {
  showToast: (toast: ToastInput) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

const TONE_ICON: Record<ToastTone, LucideIcon> = {
  success: CheckCircle2,
  danger: XCircle,
  info: Info,
};

const TONE_ICON_CLASSES: Record<ToastTone, string> = {
  success: "text-status-success",
  danger: "text-status-danger",
  info: "text-status-info",
};

/**
 * Ambient, non-blocking confirmation for the *result* of an action (e.g.
 * "Offer sent"). Never a substitute for `ConfirmActionDialog` — that remains
 * the mandatory gate *before* a sensitive action fires; this only reports
 * what already happened. See design audit "no toast/notification system".
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const nextId = useRef(0);

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const showToast = useCallback(
    ({ title, description = "", tone = "info", durationMs = 5000 }: ToastInput) => {
      const id = nextId.current++;
      setToasts((prev) => [...prev, { id, title, description, tone, durationMs }]);
      if (durationMs > 0) {
        setTimeout(() => dismiss(id), durationMs);
      }
    },
    [dismiss]
  );

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div
        aria-live="polite"
        aria-atomic="true"
        className="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex flex-col items-center gap-2 p-4 sm:items-end"
      >
        {toasts.map((toast) => {
          const Icon = TONE_ICON[toast.tone];
          return (
            <div
              key={toast.id}
              role="status"
              className={cn(
                "animate-fade-in pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-lg border border-subtle",
                "bg-surface-raised p-3.5 shadow-lg"
              )}
            >
              <Icon className={cn("mt-0.5 h-5 w-5 shrink-0", TONE_ICON_CLASSES[toast.tone])} aria-hidden="true" />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium text-primary">{toast.title}</p>
                {toast.description && (
                  <p className="mt-0.5 text-xs text-secondary">{toast.description}</p>
                )}
              </div>
              <button
                type="button"
                onClick={() => dismiss(toast.id)}
                aria-label="Dismiss notification"
                className="rounded-md p-1 text-tertiary transition-colors duration-150 hover:bg-surface-sunken hover:text-primary"
              >
                <X className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within <ToastProvider>.");
  return ctx;
}
