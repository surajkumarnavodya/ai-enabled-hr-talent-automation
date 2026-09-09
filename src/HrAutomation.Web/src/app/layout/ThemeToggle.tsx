import { Sun, Moon, MonitorSmartphone } from "lucide-react";
import { useTheme, type Theme } from "@/app/providers/ThemeProvider";
import { cn } from "@/lib/cn";

const OPTIONS: { value: Theme; label: string; icon: typeof Sun }[] = [
  { value: "light", label: "Light theme", icon: Sun },
  { value: "dark", label: "Dark theme", icon: Moon },
  { value: "system", label: "Match system theme", icon: MonitorSmartphone },
];

/** Surfaces the theme engine that already exists in ThemeProvider — previously
 * fully implemented (persisted, system-aware) but had no UI control anywhere. */
export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <div
      role="radiogroup"
      aria-label="Color theme"
      className="flex items-center gap-0.5 rounded-md border border-subtle bg-surface-sunken p-0.5"
    >
      {OPTIONS.map(({ value, label, icon: Icon }) => (
        <button
          key={value}
          type="button"
          role="radio"
          aria-checked={theme === value}
          aria-label={label}
          title={label}
          onClick={() => setTheme(value)}
          className={cn(
            "flex h-6 w-6 items-center justify-center rounded transition-colors duration-150",
            theme === value
              ? "bg-surface-raised text-brand-600 shadow-sm"
              : "text-tertiary hover:text-primary"
          )}
        >
          <Icon className="h-3.5 w-3.5" aria-hidden="true" />
        </button>
      ))}
    </div>
  );
}
