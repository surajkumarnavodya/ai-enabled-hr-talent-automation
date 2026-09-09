import { forwardRef, type InputHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  invalid?: boolean;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, invalid, ...props }, ref) => (
    <input
      ref={ref}
      aria-invalid={invalid || undefined}
      className={cn(
        "h-9 w-full rounded-md border px-3 text-sm shadow-sm transition-colors duration-150",
        "border-strong bg-surface-raised text-primary placeholder:text-tertiary",
        "focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500",
        "disabled:cursor-not-allowed disabled:bg-surface-sunken disabled:text-tertiary",
        invalid && "border-status-danger focus:border-status-danger focus:ring-status-danger",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";
