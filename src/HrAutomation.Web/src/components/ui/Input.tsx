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
        "h-9 w-full rounded-md border px-3 text-sm shadow-sm transition-colors",
        "border-slate-300 bg-white placeholder:text-slate-400 dark:border-slate-700 dark:bg-slate-900",
        "focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500",
        invalid && "border-status-danger focus:border-status-danger focus:ring-status-danger",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";
