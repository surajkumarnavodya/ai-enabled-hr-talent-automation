import { forwardRef, type SelectHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type SelectProps = SelectHTMLAttributes<HTMLSelectElement>;

export const Select = forwardRef<HTMLSelectElement, SelectProps>(({ className, ...props }, ref) => (
  <select
    ref={ref}
    className={cn(
      "h-9 w-full rounded-md border border-strong bg-surface-raised px-3 text-sm text-primary shadow-sm transition-colors duration-150",
      "focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500",
      className
    )}
    {...props}
  />
));
Select.displayName = "Select";
