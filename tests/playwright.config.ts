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
      // Allow overriding which service / protocol the tests target
      baseURL: process.env.PW_BASE_URL || 'https://nginx:8443',
      // Tests often run against self-signed or staging certs in CI/networks
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
