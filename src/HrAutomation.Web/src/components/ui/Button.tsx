import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type ButtonVariant = "primary" | "secondary" | "outline" | "ghost" | "danger";
export type ButtonSize = "sm" | "md" | "lg";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
}

/** Exported so ButtonLink.tsx can render the identical visual style on an <a> instead of a <button>. */
export const BUTTON_VARIANT_CLASSES: Record<ButtonVariant, string> = {
  primary:
    "bg-brand-600 text-white shadow-sm hover:bg-brand-700 active:bg-brand-800 disabled:bg-brand-600/50",
  secondary: "bg-surface-raised text-primary border border-subtle hover:bg-surface-sunken",
  outline: "border border-strong bg-transparent text-primary hover:bg-surface-sunken",
  ghost: "bg-transparent text-secondary hover:bg-surface-sunken hover:text-primary",
  danger: "bg-status-danger text-white shadow-sm hover:opacity-90 active:opacity-100 disabled:opacity-50",
};

export const BUTTON_SIZE_CLASSES: Record<ButtonSize, string> = {
  sm: "h-8 px-3 text-xs",
  md: "h-9 px-4 text-sm",
  lg: "h-11 px-6 text-base",
};

/**
 * Base interactive control used across the app. Every mutating action still
 * requires an explicit confirmation dialog for sensitive workflows — see
 * components/common/ConfirmActionDialog.tsx — this component just renders.
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    { className, variant = "primary", size = "md", isLoading, disabled, children, ...props },
    ref
  ) => {
    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center gap-2 rounded-md font-medium",
          "transition-[background-color,box-shadow,opacity] duration-150 ease-out",
          "disabled:cursor-not-allowed disabled:opacity-60",
          BUTTON_VARIANT_CLASSES[variant],
          BUTTON_SIZE_CLASSES[size],
          className
        )}
        disabled={disabled || isLoading}
        aria-busy={isLoading || undefined}
        {...props}
      >
        {children}
      </button>
    );
  }
);
Button.displayName = "Button";
