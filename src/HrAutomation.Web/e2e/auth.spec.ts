import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("redirects an unauthenticated visitor to /login", async ({ page }) => {
    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole("heading", { name: /hr automation platform/i })).toBeVisible();
  });

  test("mock sign-in redirects to the dashboard", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Role").selectOption("HRAdmin");
    await page.getByRole("button", { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/);
  });

  test("sign-out returns to /login", async ({ page }) => {
    await page.goto("/login");
    await page.getByRole("button", { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/);

    await page.getByRole("link", { name: /sign out/i }).click();
    await expect(page).toHaveURL(/\/login/);
  });
});
