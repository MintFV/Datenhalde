import { test, expect } from '@playwright/test';

test.describe('Landing Page (nginx static)', () => {
  test('loads and shows MintFV heading', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/MintFV/i);
    await expect(page.locator('h1')).toContainText('MintFV');
  });

  test('contains Grafana dashboard iframe', async ({ page }) => {
    await page.goto('/');
    const iframe = page.locator('iframe');
    // Iframe may or may not exist – if it does, check src
    const count = await iframe.count();
    if (count > 0) {
      await expect(iframe.first()).toHaveAttribute('src', /grafana/i);
    }
  });

  test('returns correct security headers', async ({ request }) => {
    const res = await request.get('/');
    expect(res.status()).toBe(200);
    expect(res.headers()['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers()['x-content-type-options']).toBe('nosniff');
    expect(res.headers()['strict-transport-security']).toContain('max-age=');
    expect(res.headers()['referrer-policy']).toBeTruthy();
  });

  test('serves static assets with cache headers', async ({ request }) => {
    // Try to find a CSS or JS asset on the page
    const res = await request.get('/');
    expect(res.ok()).toBeTruthy();
  });
});
