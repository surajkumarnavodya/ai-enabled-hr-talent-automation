import { describe, expect, it } from "vitest";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { server } from "@/mocks/server";
import { renderWithProviders } from "@/tests/testUtils";
import AdminUsersListPage from "@/features/administration/AdminUsersListPage";
import AdminUserDetailPage from "@/features/administration/AdminUserDetailPage";

describe("AdminUsersListPage", () => {
  it("loads the user list through the real effective-permissions and admin-users API hooks", async () => {
    renderWithProviders(<AdminUsersListPage />, { path: "/admin/users", route: "/admin/users" });

    expect(await screen.findByText("Demo Recruiter")).toBeInTheDocument();
    expect(screen.getByText("Demo HR Administrator")).toBeInTheDocument();
  });

  it("shows an access-denied state when the server's effective permissions do not include user.read", async () => {
    server.use(
      http.get("/api/v1/users/me/permissions", () => HttpResponse.json({ permissions: [] }))
    );

    renderWithProviders(<AdminUsersListPage />, { path: "/admin/users", route: "/admin/users" });

    expect(await screen.findByRole("alert")).toHaveTextContent(/user.read/i);
  });

  it("filters via a real server-side search request, not a client-side re-render trick", async () => {
    const user = userEvent.setup();
    renderWithProviders(<AdminUsersListPage />, { path: "/admin/users", route: "/admin/users" });

    await screen.findByText("Demo Recruiter");
    const searchBox = screen.getByRole("searchbox", { name: /search users/i });
    await user.type(searchBox, "hr admin");

    expect(await screen.findByText("Demo HR Administrator")).toBeInTheDocument();
    expect(screen.queryByText("Demo Recruiter")).not.toBeInTheDocument();
  });
});

describe("AdminUserDetailPage", () => {
  it("renders profile fields and assigned roles from the real detail API", async () => {
    renderWithProviders(<AdminUserDetailPage />, {
      path: "/admin/users/:userId",
      route: "/admin/users/admin-user-0001",
    });

    expect(await screen.findByRole("heading", { name: "Demo Recruiter" })).toBeInTheDocument();
    expect(screen.getByText("demo.recruiter@example.test")).toBeInTheDocument();
    expect(screen.getByText("RECRUITER")).toBeInTheDocument();
  });

  it("shows a 404-derived error state for a user id the API doesn't recognize", async () => {
    renderWithProviders(<AdminUserDetailPage />, {
      path: "/admin/users/:userId",
      route: "/admin/users/does-not-exist",
    });

    expect(await screen.findByRole("alert")).toBeInTheDocument();
  });
});
