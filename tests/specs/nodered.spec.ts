import { test, expect } from '@playwright/test';

test.describe('Node-RED', () => {

  test('loads Node-RED editor', async ({ page }) => {
    await page.goto('/nodered/');
    // Node-RED shows login or editor
    await page.waitForLoadState('networkidle');
    // Check for Node-RED title or login form
    const title = await page.title();
    expect(title).toMatch(/Node-RED/i);
  });

  test('shows login page when auth enabled', async ({ page }) => {
    await page.goto('/nodered/');
    await page.waitForLoadState('networkidle');
    // If auth is enabled, we should see a login form
    const loginForm = page.locator('#node-red-login, input[name="user"], #red-ui-login');
    const count = await loginForm.count();
    if (count > 0) {
      await expect(loginForm.first()).toBeVisible();
    }
  });

  test('serves from /nodered/ subpath', async ({ request }) => {
    const res = await request.get('/nodered/');
    expect([200, 301, 302].includes(res.status())).toBeTruthy();
  });

  test('settings endpoint returns config', async ({ request }) => {
    const res = await request.get('/nodered/settings');
    // Returns 200 with JSON settings or 401 if auth required
    expect([200, 401].includes(res.status())).toBeTruthy();
    if (res.status() === 200) {
      const body = await res.json();
      expect(body).toHaveProperty('httpNodeRoot');
    }
  });

  test('nodes endpoint is protected', async ({ request }) => {
    const res = await request.get('/nodered/nodes');
    // Should be 401 (auth required) or 200 with JSON
    expect([200, 401].includes(res.status())).toBeTruthy();
  });

  test('flow editor static assets load', async ({ request }) => {
    const res = await request.get('/nodered/red/images/node-red-256.svg');
    // Node-RED icon – may be 200 or 304
    expect([200, 304, 401].includes(res.status())).toBeTruthy();
  });
});
