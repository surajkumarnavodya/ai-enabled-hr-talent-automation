import { createContext, useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import type { AuthState, AuthenticatedUser, MockLoginInput } from "@/types/auth";
import { activeAuthProvider } from "@/features/auth/authProviderFactory";
import { safeLogger } from "@/lib/safeLogger";

export interface AuthContextValue extends AuthState {
  login: (input?: MockLoginInput) => Promise<void>;
  logout: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ status: "idle", user: null, error: null });

  useEffect(() => {
    let cancelled = false;
    setState((prev) => ({ ...prev, status: "authenticating" }));

    activeAuthProvider
      .initialize()
      .then((user) => {
        if (cancelled) return;
        setState({
          status: user ? "authenticated" : "unauthenticated",
          user,
          error: null,
        });
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        safeLogger.error("auth initialize failed", { message: (error as Error)?.message });
        setState({ status: "unauthenticated", user: null, error: "Unable to restore session." });
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (input?: MockLoginInput) => {
    setState((prev) => ({ ...prev, status: "authenticating", error: null }));
    try {
      const user: AuthenticatedUser = await activeAuthProvider.login(input);
      setState({ status: "authenticated", user, error: null });
    } catch (error) {
      setState({ status: "error", user: null, error: "Sign-in failed. Please try again." });
      safeLogger.error("login failed", { message: (error as Error)?.message });
      throw error;
    }
  }, []);

  const logout = useCallback(async () => {
    await activeAuthProvider.logout();
    setState({ status: "unauthenticated", user: null, error: null });
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ ...state, login, logout }),
    [state, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
