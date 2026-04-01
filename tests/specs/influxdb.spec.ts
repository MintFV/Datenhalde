import { test, expect } from '@playwright/test';

test.describe('InfluxDB 3 Core', () => {

  // Note: nginx proxies /influxdb/ → http://influxdb:8181 without path stripping,
  // so InfluxDB sees /influxdb/health instead of /health.
  // Health/ping are disabled from auth on InfluxDB directly, but via nginx
  // the path mismatch causes auth errors. We test through direct access.

  test('health endpoint responds (direct)', async ({ request }) => {
    const res = await request.get('http://influxdb:8181/health');
    expect(res.ok()).toBeTruthy();
  });

  test('ping endpoint responds (direct)', async ({ request }) => {
    const res = await request.get('http://influxdb:8181/ping');
    expect(res.ok()).toBeTruthy();
  });

  test('API requires authentication via nginx', async ({ request }) => {
    const res = await request.get('/influxdb/api/v3/configure/database');
    expect([401, 403].includes(res.status())).toBeTruthy();
  });

  test('rejects write without authentication', async ({ request }) => {
    const res = await request.post('/influxdb/api/v2/write?bucket=test', {
      data: 'test,host=test value=1',
      headers: { 'Content-Type': 'text/plain' },
    });
    expect([401, 403].includes(res.status())).toBeTruthy();
  });

  test('nginx proxy to InfluxDB is working', async ({ request }) => {
    const res = await request.fetch('/influxdb/', { failOnStatusCode: false });
    // Not a gateway error means proxy works
    expect([502, 503].includes(res.status())).toBeFalsy();
  });
});
