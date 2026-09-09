import { test, expect, type Page } from "@playwright/test";

async function signIn(page: Page, role: "HRRecruiter" | "HRAdmin" = "HRRecruiter") {
  await page.goto("/login");
  await page.getByLabel("Role").selectOption(role);
  await page.getByRole("button", { name: /sign in/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}

test.describe("Critical workflow guardrails", () => {
  test("candidate matching clearly labels AI output and gates shortlist approval on confirmation", async ({
    page,
  }) => {
    // Shortlist approval is HRAdmin/HiringManager-only — see
    // hooks/usePermissions.ts — so the "Approve for shortlist" action is
    // only rendered for those roles.
    await signIn(page, "HRAdmin");

    // Navigate via UI clicks, not page.goto() — the mock auth session lives
    // in memory only (by design, see features/auth/mockAuthProvider.ts) and
    // a full page navigation would reload the app and lose it, just as a
    // real unauthenticated reload would in production without a persisted
    // session mechanism.
    await page.getByRole("link", { name: /^tans$/i }).click();
    await expect(page).toHaveURL(/\/tans$/);
    await page.getByText(/senior backend engineer/i).click();
    await expect(page).toHaveURL(/\/tans\/tan-0001$/);
    await page.getByRole("link", { name: /view matches/i }).click();
    await expect(page).toHaveURL(/\/tans\/tan-0001\/matches$/);

    await expect(page.getByText(/AI recommendation — human approval required/i)).toBeVisible();

    const approveButtons = page.getByRole("button", { name: /approve for shortlist/i });
    await approveButtons.first().click();

    // Confirmation dialog must appear before anything is sent to the API.
    await expect(page.getByRole("heading", { name: /approve shortlist/i })).toBeVisible();
    await expect(page.getByText(/human decision recorded/i)).toBeVisible();

    // Cancel — this test only verifies the guardrail exists, not the mutation.
    await page.getByRole("button", { name: /cancel/i }).click();
    await expect(page.getByRole("heading", { name: /approve shortlist/i })).not.toBeVisible();
  });

  test("CV upload rejects an unsupported file type client-side before any upload occurs", async ({ page }) => {
    await signIn(page);

    await page.getByRole("link", { name: /cv bank/i }).click();
    await expect(page).toHaveURL(/\/cv-bank$/);
    await page.getByRole("link", { name: /upload cvs/i }).click();
    await expect(page).toHaveURL(/\/cv-bank\/upload$/);

    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles({
      name: "not-a-cv.exe",
      mimeType: "application/x-msdownload",
      buffer: Buffer.from("demo content"),
    });

    await expect(page.getByRole("alert")).toContainText(/unsupported file type/i);
  });
});
