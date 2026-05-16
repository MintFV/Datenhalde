import { test, expect } from '@playwright/test';

test('smoke: page content via setContent', async ({ page }) => {
  // Self-contained smoke check that does not require external services
  await page.setContent('<html><body><h1>MintFV Smoke</h1></body></html>');
  await expect(page.locator('h1')).toHaveText('MintFV Smoke');
});
