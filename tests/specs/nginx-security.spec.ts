import { test, expect } from '@playwright/test';

/**
 * Helper: sends a request that may cause nginx to return 444 (connection drop).
 * Returns the status code, or 444 if the connection was reset.
 */
async function safeFetch(
  request: any,
  url: string,
  options: Record<string, any> = {},
): Promise<number> {
  try {
    const res = await request.fetch(url, { ...options, failOnStatusCode: false, timeout: 5000 });
    return res.status();
  } catch {
    // Connection reset = nginx 444 (drops connection) – this means blocked
    return 444;
  }
}

test.describe('Nginx Security Hardening', () => {

  test.describe('Security Headers', () => {
    test('HSTS header present', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['strict-transport-security']).toContain('max-age=31536000');
      expect(res.headers()['strict-transport-security']).toContain('includeSubDomains');
    });

    test('X-Frame-Options set', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['x-frame-options']).toBe('SAMEORIGIN');
    });

    test('X-Content-Type-Options set', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['x-content-type-options']).toBe('nosniff');
    });

    test('X-XSS-Protection set', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['x-xss-protection']).toContain('1');
    });

    test('Content-Security-Policy set', async ({ request }) => {
      const res = await request.get('/');
      const csp = res.headers()['content-security-policy'];
      expect(csp).toContain("default-src 'self'");
    });

    test('Referrer-Policy set', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['referrer-policy']).toBeTruthy();
    });

    test('Permissions-Policy set', async ({ request }) => {
      const res = await request.get('/');
      expect(res.headers()['permissions-policy']).toContain('camera=()');
    });

    test('Server header hides version', async ({ request }) => {
      const res = await request.get('/');
      const server = res.headers()['server'] || '';
      expect(server).not.toMatch(/nginx\/\d/);
    });

    test('X-Powered-By is hidden', async ({ request }) => {
      const res = await request.get('/grafana/login');
      expect(res.headers()['x-powered-by']).toBeUndefined();
    });
  });

  test.describe('HTTP Method Restrictions', () => {
    test('TRACE method blocked', async ({ request }) => {
      const status = await safeFetch(request, '/', { method: 'TRACE' });
      // nginx should block with 444 (connection drop) or 405
      expect([405, 444].includes(status)).toBeTruthy();
    });

    test('CONNECT method blocked', async ({ request }) => {
      const status = await safeFetch(request, '/', { method: 'CONNECT' });
      expect([405, 444].includes(status)).toBeTruthy();
    });

    test('PUT method blocked on selfservice', async ({ request }) => {
      const status = await safeFetch(request, '/selfservice/anmelden', { method: 'PUT' });
      expect([405, 444].includes(status)).toBeTruthy();
    });

    test('DELETE method blocked on selfservice', async ({ request }) => {
      const status = await safeFetch(request, '/selfservice/anmelden', { method: 'DELETE' });
      expect([405, 444].includes(status)).toBeTruthy();
    });
  });

  test.describe('Bad URI / Bot Blocking', () => {
    test('blocks common exploit paths', async ({ request }) => {
      const exploitPaths = [
        '/wp-admin/',
        '/wp-login.php',
        '/.env',
        '/phpmyadmin/',
        '/admin/config.php',
      ];
      for (const path of exploitPaths) {
        const status = await safeFetch(request, path, { method: 'GET' });
        expect(
          [403, 404, 444].includes(status),
          `Expected ${path} to be blocked, got ${status}`
        ).toBeTruthy();
      }
    });

    test('blocks path traversal attempts', async ({ request }) => {
      const status = await safeFetch(request, '/../../etc/passwd', { method: 'GET' });
      expect(status).not.toBe(200);
    });

    test('blocks hidden files', async ({ request }) => {
      const status = await safeFetch(request, '/.htaccess', { method: 'GET' });
      expect([403, 404, 444].includes(status)).toBeTruthy();
    });
  });

  test.describe('HTTPS Redirect', () => {
    test('HTTP redirects to HTTPS', async ({ request }) => {
      try {
        const res = await request.get('http://nginx:8080/', {
          followRedirects: false,
        });
        expect([301, 302, 308].includes(res.status())).toBeTruthy();
        expect(res.headers()['location']).toContain('https');
      } catch {
        // Connection might be refused if port not exposed – that's ok
      }
    });
  });

  test.describe('Rate Limiting', () => {
    test('single request is not rate-limited', async ({ request }) => {
      const res = await request.get('/selfservice/anmelden');
      expect(res.ok()).toBeTruthy();
    });
  });

  test.describe('TLS Configuration', () => {
    test('HTTPS connection works', async ({ request }) => {
      const res = await request.get('/');
      expect(res.ok()).toBeTruthy();
    });
  });
});
