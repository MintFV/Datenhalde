import { defineConfig } from '@playwright/test';

/**
 * MintFV Playwright Test Configuration
 *
 * Tests run inside Docker on the mintfv-network.
 * Services are accessed via their Docker service names.
 */
export default defineConfig({
  testDir: './specs',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 1,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: '/tests/report' }],
  ],
  use: {
    // Via nginx inside Docker network
    baseURL: 'https://nginx:8443',
    ignoreHTTPSErrors: true,
    locale: 'de-DE',
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});
