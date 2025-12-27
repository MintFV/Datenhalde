# Node-RED Installation - Test Report

**Datum:** 27. Dezember 2025  
**System:** MintFV @ mintfv.peddy.net

## ✅ Erfolgreich abgeschlossene Arbeiten

### 1. Container Setup ✅
- [x] Docker Compose Service konfiguriert
- [x] User/Group: 2004:2100 ✅
- [x] Verzeichnis `./nodered/data` erstellt
- [x] Permissions korrekt gesetzt (750)
- [x] Container gestartet und läuft stabil

### 2. Networking & Reverse Proxy ✅
- [x] nginx Location `/nodered/` konfiguriert
- [x] Rate Limiting: 30 req/s, burst 50 ✅
- [x] WebSocket Support aktiviert
- [x] HTTPS Zugriff funktioniert: https://mintfv.peddy.net/nodered/
- [x] HTTP → HTTPS Redirect funktioniert

### 3. Container Health ✅
- [x] Healthcheck mit `curl -fsS` implementiert
- [x] Container Status: `Up 2 minutes (healthy)`
- [x] Node-RED Version: v4.1.2
- [x] Node.js Version: v20.19.6

### 4. Dateistruktur ✅
```
./nodered/data/
├── settings.js         (25840 bytes) - Hauptkonfiguration
├── package.json        (120 bytes)   - npm dependencies
├── flows.json          (erstellt)    - Flow Definitionen
├── .config.*.json      (erstellt)    - Node-RED Config
├── lib/                (Verzeichnis) - Bibliotheken
└── node_modules/       (Verzeichnis) - npm Packages
```

### 5. Dokumentation ✅
- [x] Vollständige Dokumentation: [NODERED.md](NODERED.md)
- [x] Quick Start Guide: [NODERED-QUICKSTART.md](NODERED-QUICKSTART.md)
- [x] README aktualisiert
- [x] Copilot Instructions aktualisiert

## 🟡 Noch zu erledigen (Initial Setup)

### Sicherheit & Authentifizierung
- [ ] **adminAuth aktivieren** (Container läuft aktuell OFFEN!)
  - Passwort-Hash generieren: `docker compose exec nodered node-red admin hash-pw`
  - settings.js editieren (Zeile ~76)
  - Container neu starten
  
- [ ] **credentialSecret setzen** (für verschlüsselte Credentials)
  - Secret generieren: `openssl rand -hex 32`
  - settings.js editieren (Zeile ~44)
  - Container neu starten

### Reverse Proxy Konfiguration
- [ ] **httpAdminRoot & httpNodeRoot setzen**
  - settings.js editieren (Zeile ~170, ~194)
  - Werte: `/nodered` für beide
  - Container neu starten
  - **Aktuell**: Funktioniert auch ohne, aber Best Practice für Subdirectory Setup

### InfluxDB Integration
- [ ] **InfluxDB Node installieren**
  - Im UI: Manage palette → Install → `node-red-contrib-influxdb`
  - Oder CLI: `docker compose exec nodered npm install node-red-contrib-influxdb`
  
- [ ] **InfluxDB Connection konfigurieren**
  - Server: http://influxdb:8181
  - Token: Admin Token aus `./influxdb/tokens/admin.token`
  - Bucket: `mintfv`
  
- [ ] **Test-Flow erstellen & deployen**
  - Inject → Function → InfluxDB Out
  - Daten in InfluxDB verifizieren

## 📊 Test-Ergebnisse

### Test 1: HTTPS Zugriff ✅
```bash
curl -fsS https://mintfv.peddy.net/nodered/
```
**Ergebnis:** ✅ HTML mit "Node-RED" Header empfangen

### Test 2: Container Healthcheck ✅
```bash
docker compose ps nodered
```
**Ergebnis:** ✅ `Up 2 minutes (healthy)`

### Test 3: API Erreichbarkeit ✅
```bash
curl -fsS https://mintfv.peddy.net/nodered/settings
```
**Ergebnis:** ✅ API antwortet mit JSON Settings

### Test 4: Dateisystem ✅
```bash
docker compose exec nodered ls -la /data
```
**Ergebnis:** ✅ Alle Dateien korrekt erstellt mit richtigen Permissions

### Test 5: Logs ✅
```bash
docker compose logs nodered
```
**Ergebnis:** ✅ Keine Fehler, Server läuft auf Port 1880

## ⚠️ Wichtige Hinweise

### Sicherheitsrisiko: Keine Authentifizierung!
**AKTUELLER STATUS:** Node-RED läuft **OHNE LOGIN-SCHUTZ**!

Jeder kann auf https://mintfv.peddy.net/nodered/ zugreifen und:
- Flows bearbeiten/löschen
- Code ausführen
- Daten einsehen
- Credentials ändern

**DRINGEND:** Vor Produktiveinsatz `adminAuth` aktivieren!

### credentialSecret Warnung
Die Node-RED Logs zeigen:
```
Your flow credentials file is encrypted using a system-generated key.
You should set your own key using the 'credentialSecret' option.
```

**Empfehlung:** Eigenen `credentialSecret` setzen bevor Credentials angelegt werden!

### Multi-Tenancy
Node-RED ist **NICHT multi-tenant fähig**:
- Ein Workspace für alle User
- Keine User-spezifische Isolation
- Nur "Admin" oder "Read-Only" Rechte

Für echte Multi-Tenancy: Separate Container-Instanzen pro Tenant!

## 🚀 Nächste Schritte

### Priorität 1: Sicherheit ⚠️
1. adminAuth aktivieren (siehe [NODERED-QUICKSTART.md](NODERED-QUICKSTART.md))
2. credentialSecret setzen
3. Login testen

### Priorität 2: Reverse Proxy
1. httpAdminRoot & httpNodeRoot setzen
2. Container neu starten
3. Pfade testen

### Priorität 3: InfluxDB Integration
1. node-red-contrib-influxdb installieren
2. Connection konfigurieren
3. Test-Flow erstellen
4. Daten in InfluxDB verifizieren

### Priorität 4: Zusätzliche Nodes
- `node-red-dashboard` - Dashboard UI
- `node-red-contrib-cron-plus` - Cron Scheduler
- `node-red-node-email` - Email Versand

## 📦 Installierte Software

| Component | Version | Status |
|-----------|---------|--------|
| Node-RED | v4.1.2 | ✅ Running |
| Node.js | v20.19.6 | ✅ Active |
| Container | nodered/node-red:latest | ✅ Healthy |
| nginx Proxy | Configured | ✅ Working |
| SSL/HTTPS | Let's Encrypt Production | ✅ Valid |

## 📝 Konfigurationsdateien

| Datei | Pfad | Status | Nächste Aktion |
|-------|------|--------|----------------|
| docker-compose.yaml | `/home/peddy/mintfv/` | ✅ Konfiguriert | - |
| nginx ssl.conf | `./nginx/conf/ssl.conf` | ✅ Konfiguriert | - |
| rate-limits.conf | `./nginx/conf/00-rate-limits.conf` | ✅ Konfiguriert | - |
| settings.js | `./nodered/data/settings.js` | 🟡 Default | adminAuth + credentialSecret setzen |
| flows.json | `./nodered/data/flows.json` | ✅ Erstellt | Flows anlegen |

## 🔗 Wichtige Links

- **Node-RED UI:** https://mintfv.peddy.net/nodered/
- **Quick Start:** [NODERED-QUICKSTART.md](NODERED-QUICKSTART.md)
- **Full Docs:** [NODERED.md](NODERED.md)
- **InfluxDB Docs:** [INFLUXDB.md](INFLUXDB.md)
- **Official Docs:** https://nodered.org/docs/

---

**Test durchgeführt von:** GitHub Copilot  
**Test Status:** ✅ Installation erfolgreich - Konfiguration ausstehend
