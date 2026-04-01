import { test, expect } from '@playwright/test';

test.describe('Grafana', () => {

  test('health API returns ok', async ({ request }) => {
    const res = await request.get('/grafana/api/health');
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.database).toBe('ok');
  });

  test('loads Grafana login page', async ({ page }) => {
    await page.goto('/grafana/login');
    await expect(page.locator('input[name="user"]')).toBeVisible({ timeout: 15_000 });
    await expect(page.locator('input[name="password"]')).toBeVisible();
  });

  test('shows Grafana branding', async ({ page }) => {
    await page.goto('/grafana/login');
    await expect(page.getByRole('heading', { name: /Grafana/i })).toBeVisible({ timeout: 15_000 });
  });

  test('rejects invalid credentials', async ({ page }) => {
    await page.goto('/grafana/login');
    await page.fill('input[name="user"]', 'invaliduser');
    await page.fill('input[name="password"]', 'invalidpass');
    await page.click('button[type="submit"]');
    // Grafana v12 shows an alert or error message after failed login
    await expect(page.locator('[data-testid="data-testid Alert error"], [aria-label*="error"], .css-1gd3bhc, div[class*="alert"]')).toBeVisible({ timeout: 10_000 });
  });

  test('API requires authentication', async ({ request }) => {
    const res = await request.get('/grafana/api/dashboards/home');
    expect(res.status()).toBe(401);
  });

  test('serves from /grafana/ subpath correctly', async ({ request }) => {
    const res = await request.get('/grafana/');
    // Should redirect to login or serve content
    expect([200, 302].includes(res.status())).toBeTruthy();
  });

  test('WebSocket upgrade support (live endpoint)', async ({ request }) => {
    // Grafana uses WebSockets for live features – just check the endpoint exists
    const res = await request.get('/grafana/api/live/ws', {
      headers: { 'Upgrade': 'websocket', 'Connection': 'Upgrade' }
    });
    // Should get 401 (auth required) or 426 (upgrade required), not 404
    expect(res.status()).not.toBe(404);
  });
});
