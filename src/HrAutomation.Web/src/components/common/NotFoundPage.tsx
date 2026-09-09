import { SearchX } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/Button";

/** Explicit catch-all for any path that matches no registered route. */
export default function NotFoundPage() {
  const navigate = useNavigate();
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-6 text-center">
      <SearchX className="mb-3 h-10 w-10 text-status-neutral" aria-hidden="true" />
      <h1 className="mb-2 text-lg font-semibold text-slate-900 dark:text-slate-100">
        Page not found
      </h1>
      <p className="mb-4 max-w-md text-sm text-slate-600 dark:text-slate-400">
        The page you're looking for doesn't exist or may have moved.
      </p>
      <Button onClick={() => navigate("/dashboard")}>Back to dashboard</Button>
    </div>
  );
}
