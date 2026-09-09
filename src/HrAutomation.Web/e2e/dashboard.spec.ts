import { test, expect, type Page } from "@playwright/test";

async function signIn(page: Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /sign in/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}

test.describe("Dashboard", () => {
  test("shows the cross-workflow summary tiles", async ({ page }) => {
    await signIn(page);

    await expect(page.getByText(/active tans/i)).toBeVisible();
    await expect(page.getByText(/candidates awaiting review/i)).toBeVisible();
    await expect(page.getByText(/interviews scheduled today/i)).toBeVisible();
    await expect(page.getByText(/high-severity discrepancies/i)).toBeVisible();
    await expect(page.getByText(/workflow alerts & sla breaches/i)).toBeVisible();
  });

  test("sidebar navigation reaches the TAN list", async ({ page }) => {
    await signIn(page);
    await page.getByRole("link", { name: /^tans$/i }).click();
    await expect(page).toHaveURL(/\/tans$/);
    await expect(page.getByRole("heading", { name: /tans \/ job requisitions/i })).toBeVisible();
  });
});
