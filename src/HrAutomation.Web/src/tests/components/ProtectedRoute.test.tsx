import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { AuthContext, type AuthContextValue } from "@/features/auth/AuthContext";
import { ProtectedRoute } from "@/app/router/ProtectedRoute";
import { PermissionRoute } from "@/app/router/PermissionRoute";
import AccessDeniedPage from "@/features/auth/pages/AccessDeniedPage";

function renderWithAuthState(authValue: AuthContextValue, initialEntry: string) {
  return render(
    <AuthContext.Provider value={authValue}>
      <MemoryRouter initialEntries={[initialEntry]}>
        <Routes>
          <Route path="/login" element={<div>Sign-in page</div>} />
          <Route path="/access-denied" element={<AccessDeniedPage />} />
          <Route element={<ProtectedRoute />}>
            <Route path="/dashboard" element={<div>Dashboard content</div>} />
            <Route element={<PermissionRoute permission="admin.access" />}>
              <Route path="/admin" element={<div>Admin content</div>} />
            </Route>
          </Route>
        </Routes>
      </MemoryRouter>
    </AuthContext.Provider>
  );
}

const noop = async () => {};

describe("ProtectedRoute", () => {
  it("redirects to /login when unauthenticated", () => {
    renderWithAuthState(
      { status: "unauthenticated", user: null, error: null, login: noop, logout: noop },
      "/dashboard"
    );
    expect(screen.getByText("Sign-in page")).toBeInTheDocument();
  });

  it("renders the protected content when authenticated", () => {
    renderWithAuthState(
      {
        status: "authenticated",
        user: { userId: "u1", tenantId: "t1", displayName: "Demo User", role: "HR_ADMIN" },
        error: null,
        login: noop,
        logout: noop,
      },
      "/dashboard"
    );
    expect(screen.getByText("Dashboard content")).toBeInTheDocument();
  });
});

describe("PermissionRoute", () => {
  it("shows the access-denied state for a role lacking the required permission", () => {
    renderWithAuthState(
      {
        status: "authenticated",
        user: { userId: "u2", tenantId: "t1", displayName: "Demo Recruiter", role: "RECRUITER" },
        error: null,
        login: noop,
        logout: noop,
      },
      "/admin"
    );
    expect(screen.getByRole("heading", { name: /access denied/i })).toBeInTheDocument();
  });

  it("renders the route when the role has the required permission", () => {
    renderWithAuthState(
      {
        status: "authenticated",
        user: { userId: "u3", tenantId: "t1", displayName: "Demo Admin", role: "HR_ADMIN" },
        error: null,
        login: noop,
        logout: noop,
      },
      "/admin"
    );
    expect(screen.getByText("Admin content")).toBeInTheDocument();
  });
});
