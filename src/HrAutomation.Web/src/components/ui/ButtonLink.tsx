import { forwardRef } from "react";
import { Link, type LinkProps } from "react-router-dom";
import { cn } from "@/lib/cn";
import { BUTTON_VARIANT_CLASSES, BUTTON_SIZE_CLASSES, type ButtonVariant, type ButtonSize } from "@/components/ui/Button";

export interface ButtonLinkProps extends LinkProps {
  variant?: ButtonVariant;
  size?: ButtonSize;
}

/**
 * A navigation control styled identically to <Button> but rendering a single
 * <a> (via react-router's Link) as its root element — never a <button>
 * nested inside an <a>. That nesting is invalid HTML and produces an
 * unreliable accessibility tree (which is exactly what real Button-inside-Link
 * markup previously did across several feature pages before this component
 * existed). Use this for any "navigate somewhere" action; use <Button> only
 * for in-place actions (submit, open dialog, trigger mutation).
 */
export const ButtonLink = forwardRef<HTMLAnchorElement, ButtonLinkProps>(
  ({ className, variant = "primary", size = "md", ...props }, ref) => (
    <Link
      ref={ref}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors",
        BUTTON_VARIANT_CLASSES[variant],
        BUTTON_SIZE_CLASSES[size],
        className
      )}
      {...props}
    />
  )
);
ButtonLink.displayName = "ButtonLink";
