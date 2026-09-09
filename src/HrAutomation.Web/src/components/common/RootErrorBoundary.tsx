import { Component, type ErrorInfo, type ReactNode } from "react";
import { safeLogger } from "@/lib/safeLogger";

interface Props {
  children: ReactNode;
}
interface State {
  hasError: boolean;
}

/**
 * Last-resort boundary for uncaught render errors. Never displays the raw
 * error/stack trace to the user — only a generic, user-safe message. See
 * docs/05-security-governance/frontend-security.md "Never show raw backend
 * stack traces in UI" (extended here to frontend errors too).
 */
export class RootErrorBoundary extends Component<Props, State> {
  override state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  override componentDidCatch(error: Error, info: ErrorInfo): void {
    safeLogger.error("uncaught render error", {
      message: error.message,
      componentStack: info.componentStack ? "present" : "absent",
    });
  }

  override render() {
    if (this.state.hasError) {
      return (
        <div className="flex min-h-screen items-center justify-center p-6 text-center">
          <div>
            <h1 className="mb-2 text-lg font-semibold text-slate-900">Something went wrong</h1>
            <p className="text-sm text-slate-600">
              Please refresh the page. If the problem continues, contact support.
            </p>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
