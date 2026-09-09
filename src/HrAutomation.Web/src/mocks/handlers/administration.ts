import { http, HttpResponse } from "msw";
import { mockAdminUserDetails, mockAdminUsers, mockEffectivePermissions } from "@/mocks/data/administration";
import type { AdminUserListItemDto, CursorPage } from "@/types/api";

export const administrationHandlers = [
  http.get("/api/v1/users/me/permissions", () => HttpResponse.json(mockEffectivePermissions)),

  http.get("/api/v1/admin/users", ({ request }) => {
    const search = new URL(request.url).searchParams.get("search")?.toLowerCase();
    const items = search
      ? mockAdminUsers.filter(
          (u) => u.display_name.toLowerCase().includes(search) || u.email.toLowerCase().includes(search)
        )
      : mockAdminUsers;
    const page: CursorPage<AdminUserListItemDto> = { items, next_cursor: null };
    return HttpResponse.json(page);
  }),

  http.get("/api/v1/admin/users/:userId", ({ params }) => {
    const detail = mockAdminUserDetails[params.userId as string];
    if (!detail) return HttpResponse.json({ title: "Not found" }, { status: 404 });
    return HttpResponse.json(detail);
  }),
];
