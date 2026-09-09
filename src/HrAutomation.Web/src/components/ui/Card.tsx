import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type CardElevation = "flat" | "raised";

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  /** "raised" adds a stronger shadow — use sparingly, for the one primary
   * surface on a screen, not as a new default (see design audit "cards have
   * no elevation hierarchy"). */
  elevation?: CardElevation;
}

const ELEVATION_CLASSES: Record<CardElevation, string> = {
  flat: "shadow-sm",
  raised: "shadow-md",
};

export function Card({ className, elevation = "flat", ...props }: CardProps) {
  return (
    <div
      className={cn(
        "rounded-lg border border-subtle bg-surface-raised",
        ELEVATION_CLASSES[elevation],
        className
      )}
      {...props}
    />
  );
}

export function CardHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("border-b border-subtle p-4", className)} {...props} />;
}

export function CardContent({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("p-4", className)} {...props} />;
}
