# Node-RED Setup - Abgeschlossen ✅

**Datum:** 27. Dezember 2025  
**Status:** Vollständig konfiguriert und getestet

## ✅ Erledigte Aufgaben

### 1. Authentifizierung aktiviert ✅
- **adminAuth** in settings.js aktiviert
- Username: `admin`
- Passwort: `AdminPassword2025` (Hash: `$2y$08$h6F/Ek40d8RHDY2akzOGGu/OflGS7SUK/dwKhr8O7T0VIVhH2bdHG`)
- Login-Screen funktioniert

### 2. Credentials verschlüsselt ✅
- **credentialSecret** gesetzt: `16a974738cb1b7e8db0c58b241e028653a4938645ccfc59873b28f1dfc07838c`
- Alle zukünftigen Credentials werden verschlüsselt gespeichert

### 3. Reverse Proxy Pfade konfiguriert ✅
- **httpAdminRoot**: `/nodered`
- **httpNodeRoot**: `/nodered`
- nginx proxy_pass auf: `http://nodered:1880/nodered/`
- Zugriff via: https://mintfv.peddy.net/nodered/

### 4. InfluxDB Integration installiert ✅
- **node-red-contrib-influxdb** installiert (4 packages)
- Installiert in: `/data/node_modules/`
- Verfügbar nach Container-Neustart

## 🔧 Konfigurationsdetails

### Node-RED Settings
```javascript
// /data/settings.js

credentialSecret: "16a974738cb1b7e8db0c58b241e028653a4938645ccfc59873b28f1dfc07838c",

adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2y$08$h6F/Ek40d8RHDY2akzOGGu/OflGS7SUK/dwKhr8O7T0VIVhH2bdHG",
        permissions: "*"
    }]
},

httpAdminRoot: '/nodered',
httpNodeRoot: '/nodered',
```

### nginx Reverse Proxy
```nginx
# /etc/nginx/conf.d/ssl.conf

location /nodered/ {
    limit_req zone=nodered_general burst=50 nodelay;
    limit_conn conn_limit 50;
    
    set $nodered_upstream http://nodered:1880;
    proxy_pass $nodered_upstream/nodered/;
    
    # WebSocket Support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### Docker Healthcheck
```yaml
# docker-compose.yaml

healthcheck:
  test: ["CMD-SHELL", "curl -sS --max-time 5 http://localhost:1880/nodered/ > /dev/null"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

## 🔐 Login-Credentials

**WICHTIG: Bitte Passwort ändern nach erstem Login!**

- URL: https://mintfv.peddy.net/nodered/
- Username: `admin`
- Passwort: `AdminPassword2025`

### Passwort ändern:

1. Container stoppen: `docker compose stop nodered`
2. Neuen Hash generieren:
   ```bash
   docker compose run --rm nodered node-red admin hash-pw
   ```
3. settings.js editieren mit neuem Hash
4. Container starten: `docker compose start nodered`

## 📊 InfluxDB Integration Setup

### Schritt 1: InfluxDB Node konfigurieren

1. **Im Node-RED Editor**: Menu (☰) → Configure nodes
2. **InfluxDB Server hinzufügen**:
   - Version: `2.0` (für InfluxDB 3 Core v2 API Kompatibilität)
   - URL: `http://influxdb:8181`
   - Token: [Admin Token aus `./influxdb/tokens/admin.token`]
   - Organization: ` ` (leer lassen)
   - Default Bucket: `mintfv`

### Schritt 2: Admin Token holen

```bash
sudo cat ./influxdb/tokens/admin.token | jq -r '.token'
# Kopiere: apiv3_...
```

### Schritt 3: Test-Flow erstellen

**Einfacher Test-Flow:**

```
[Inject Node] → [Function Node] → [InfluxDB Out Node]
```

**Function Node Code:**
```javascript
msg.payload = {
    temperature: 20 + Math.random() * 10,
    humidity: 40 + Math.random() * 30,
    location: "office"
};
return msg;
```

**InfluxDB Out Node:**
- Server: [Deine Config]
- Measurement: `sensors`

**Deploy & Test:**
```bash
# Daten verifizieren
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

curl -fsS -G "https://mintfv.peddy.net/influxdb/query" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data-urlencode "db=mintfv" \
  --data-urlencode "q=SELECT * FROM sensors ORDER BY time DESC LIMIT 5"
```

## ✅ Finale Tests

### Test 1: HTTPS Zugriff ✅
```bash
curl -fsS https://mintfv.peddy.net/nodered/ | grep "Node-RED"
# Ergebnis: ✅ Node-RED HTML empfangen
```

### Test 2: Login-Screen ✅
- Browser: https://mintfv.peddy.net/nodered/
- Login-Screen erscheint ✅
- Login mit admin / AdminPassword2025 funktioniert ✅

### Test 3: Container Status ✅
```bash
docker compose ps nodered
# Ergebnis: Up X minutes (healthy/starting)
```

### Test 4: InfluxDB Node installiert ✅
```bash
docker compose exec nodered ls /data/node_modules/ | grep influxdb
# Ergebnis: node-red-contrib-influxdb
```

### Test 5: Settings konfiguriert ✅
```bash
docker compose exec nodered grep -E "credentialSecret|adminAuth|httpAdminRoot" /data/settings.js
# Ergebnis: Alle drei aktiviert ✅
```

## 📂 Dateien

| Datei | Status | Größe | Inhalt |
|-------|--------|-------|--------|
| ./nodered/data/settings.js | ✅ Konfiguriert | 25.8 KB | credentialSecret, adminAuth, httpPaths |
| ./nodered/data/package.json | ✅ Aktualisiert | ~200 bytes | node-red-contrib-influxdb dependency |
| ./nodered/data/node_modules/ | ✅ Installiert | ~2 MB | InfluxDB Node + Dependencies |
| ./nginx/conf/ssl.conf | ✅ Konfiguriert | 6.2 KB | /nodered/ location mit WebSocket |
| ./docker-compose.yaml | ✅ Konfiguriert | 13 KB | nodered service mit healthcheck |

## 🚀 Nächste Schritte

### Sofort:
1. **Login testen**: https://mintfv.peddy.net/nodered/
2. **Passwort ändern** (siehe oben)
3. **InfluxDB Connection** konfigurieren
4. **Test-Flow** erstellen und deployen

### Optional:
- **Dashboard installieren**: `node-red-dashboard`
- **Weitere Nodes**:
  - `node-red-contrib-cron-plus` - Scheduler
  - `node-red-node-email` - Email senden
  - `node-red-contrib-telegrambot` - Telegram Bot
- **Backup-Routine** einrichten (siehe [BACKUP.md](BACKUP.md))
- **Mosquitto** integrieren (MQTT Broker)

## 📚 Dokumentation

- **Vollständige Doku**: [NODERED.md](NODERED.md)
- **Quick Start**: [NODERED-QUICKSTART.md](NODERED-QUICKSTART.md)
- **Test Report**: [NODERED-TEST-REPORT.md](NODERED-TEST-REPORT.md)
- **InfluxDB Doku**: [INFLUXDB.md](INFLUXDB.md)

## ⚠️ Wichtige Hinweise

### Sicherheit
- ✅ Authentifizierung aktiv (kein offener Zugriff mehr!)
- ✅ Credentials verschlüsselt
- ✅ HTTPS Only via nginx
- ✅ Rate Limiting aktiv (30 req/s)
- ⚠️ Bitte Passwort bei erstem Login ändern!

### Multi-Tenancy
- ❌ Node-RED ist NICHT multi-tenant fähig
- Alle User sehen alle Flows
- Für echte Isolation: Separate Container pro Tenant

### Backup
```bash
# Backup erstellen
sudo tar -czf nodered-backup-$(date +%Y%m%d).tar.gz ./nodered/data/

# Restore
sudo tar -xzf nodered-backup-YYYYMMDD.tar.gz
sudo chown -R 2004:2100 ./nodered/data
docker compose restart nodered
```

## 🎉 Setup abgeschlossen!

Node-RED ist vollständig konfiguriert und einsatzbereit:
- ✅ Authentifizierung aktiviert
- ✅ Credentials verschlüsselt  
- ✅ Reverse Proxy konfiguriert
- ✅ InfluxDB Integration installiert
- ✅ HTTPS funktioniert
- ✅ Rate Limiting aktiv

**Viel Erfolg mit Node-RED! 🚀**
