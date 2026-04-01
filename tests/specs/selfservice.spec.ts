import { test, expect } from '@playwright/test';

// Selfservice has rate limiting (5r/s, burst 30 + global 10r/s, burst 30).
// Tests are consolidated to minimize page loads.

test.describe('Selfservice Portal', () => {

  test('health endpoint returns ok JSON', async ({ request }) => {
    const res = await request.get('/selfservice/health');
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  test('root redirects to login for unauthenticated users', async ({ page }) => {
    await page.goto('/selfservice/');
    await expect(page).toHaveURL(/anmelden|dashboard/);
  });

  // NOTE: /selfservice/dashboard redirect uses ?next=%2Fselfservice%2Fdashboard
  // which is blocked by nginx's is_malformed_uri rule (%2f detection).
  // Known Flask/nginx conflict – tested via API.
  test('dashboard requires authentication (API)', async ({ request }) => {
    const res = await request.fetch('/selfservice/dashboard', {
      maxRedirects: 0,
    });
    expect(res.status()).toBe(302);
    const location = res.headers()['location'] || '';
    expect(location).toContain('anmelden');
  });

  test('login page: form, branding, links, bootstrap', async ({ page }) => {
    await page.goto('/selfservice/anmelden');

    await expect(page).toHaveTitle(/Anmelden/);
    await expect(page.locator('.navbar-brand')).toContainText('MintFV Selfservice');
    await expect(page.locator('input[name="email"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    await expect(page.locator('input[type="submit"]')).toBeVisible();
    await expect(page.locator('a[href*="registrieren"]')).toBeVisible();
    await expect(page.locator('a[href*="passwort-vergessen"]')).toBeVisible();

    // Bootstrap & responsive
    const bootstrapLink = page.locator('link[href*="bootstrap"]');
    await expect(bootstrapLink.first()).toHaveAttribute('href', /bootstrap/);
    const viewport = page.locator('meta[name="viewport"]');
    await expect(viewport).toHaveAttribute('content', /width=device-width/);
  });

  // Consolidate all other page checks into a single browser session
  // to stay within rate limits (reuses same page/context).
  test('all auth pages load correctly', async ({ page }) => {
    // Registration
    await page.goto('/selfservice/registrieren');
    await expect(page).toHaveTitle(/Registrieren/);
    await expect(page.locator('input[name="email"]')).toBeVisible();
    await expect(page.locator('input[name="display_name"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    await expect(page.locator('input[name="password_confirm"]')).toBeVisible();
    await expect(page.locator('a[href="/selfservice/anmelden"]')).toBeVisible();

    // Forgot Password (navigate from same context, reuses connection)
    await page.goto('/selfservice/passwort-vergessen');
    await expect(page).toHaveTitle(/Passwort vergessen/);
    await expect(page.locator('input[name="email"]')).toBeVisible();
    await expect(page.locator('a[href*="anmelden"]')).toBeVisible();

    // Resend Verification
    await page.goto('/selfservice/verifizierung-erneut-senden');
    await expect(page).toHaveTitle(/Bestätigung erneut senden/);
    await expect(page.locator('input[name="email"]')).toBeVisible();
  });

  test('shows error on invalid login', async ({ page }) => {
    await page.goto('/selfservice/anmelden');
    await page.fill('input[name="email"]', 'nonexistent@example.com');
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('input[type="submit"]');
    await expect(page.locator('.alert-danger, .flash-container .alert')).toBeVisible();
  });
});
