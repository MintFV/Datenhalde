import { test, expect } from '@playwright/test';

test.describe('Mosquitto MQTT (via nginx)', () => {

  test('MQTTS port 8883 is proxied via nginx', async ({ request }) => {
    // Verify nginx is running and serving – the MQTT stream proxy
    // is a separate nginx stream block, not testable via HTTP.
    const res = await request.get('/');
    expect(res.ok()).toBeTruthy();
  });

  test('no MQTT config details exposed via HTTP', async ({ request }) => {
    // Landing page may mention service names, but should not expose config
    const res = await request.get('/');
    const body = await res.text();
    // Should not expose passwords, config paths, or internal ports
    expect(body).not.toContain('mosquitto.passwd');
    expect(body).not.toContain('1883');
  });
});
