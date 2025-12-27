# Node-RED Quick Start Guide

## ✅ Installation Status

- [x] Container läuft: `mintfv-nodered` (v4.1.2)
- [x] HTTPS Zugriff: https://mintfv.peddy.net/nodered/
- [x] Reverse Proxy funktioniert
- [ ] Authentifizierung aktiviert (Standard: OFFEN!)
- [ ] credentialSecret gesetzt
- [ ] Reverse Proxy Pfade konfiguriert
- [ ] InfluxDB Integration getestet

## 🔒 Schritt 1: Authentifizierung aktivieren (WICHTIG!)

**Aktuell läuft Node-RED OHNE Login-Schutz!** Jeder kann auf den Editor zugreifen.

### 1.1 Passwort-Hash generieren

```bash
docker compose exec nodered node-red admin hash-pw
# Gib dein Passwort ein (z.B. "SecurePassword123!")
# Kopiere den Hash: $2y$08$...
```

### 1.2 settings.js editieren

```bash
docker compose stop nodered
nano ./nodered/data/settings.js
```

**Suche nach Zeile ~76** und aktiviere `adminAuth`:

```javascript
// VORHER (auskommentiert):
//adminAuth: {
//    type: "credentials",
//    users: [{
//        username: "admin",
//        password: "$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN.",
//        permissions: "*"
//    }]
//},

// NACHHER (aktiviert mit DEINEM Hash):
adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2y$08$DEIN_GENERIERTER_HASH_HIER",
        permissions: "*"
    }]
},
```

### 1.3 Container neu starten

```bash
docker compose start nodered
docker compose logs -f nodered  # Prüfe auf Fehler
```

### 1.4 Login testen

Browser: https://mintfv.peddy.net/nodered/

- Login-Screen sollte erscheinen
- Username: `admin`
- Password: Dein gewähltes Passwort

## 🔐 Schritt 2: Credentials verschlüsseln

**In derselben settings.js** (Zeile ~44):

```javascript
// VORHER:
//credentialSecret: "a-secret-key",

// NACHHER (mit eigenem Secret):
credentialSecret: "56ca4d1716853e5a39badad0f36cbff2e62725df80ce5430368273c02891f087",
```

**Secret generieren:**
```bash
openssl rand -hex 32
```

**⚠️ Wichtig**: Nach dem ersten Setzen NICHT mehr ändern - sonst sind alle Credentials verloren!

## 🔄 Schritt 3: Reverse Proxy Pfade konfigurieren

**In settings.js** (Zeile ~170 und ~194):

```javascript
// VORHER:
//httpAdminRoot: '/admin',
//httpNodeRoot: '/red-nodes',

// NACHHER:
httpAdminRoot: '/nodered',
httpNodeRoot: '/nodered',
```

**Container neu starten:**
```bash
docker compose restart nodered
```

## 📊 Schritt 4: InfluxDB Node installieren

### 4.1 Im Node-RED UI

1. Menu (☰) → Manage palette → Install
2. Suche: `node-red-contrib-influxdb`
3. Install klicken
4. Warten bis Installation abgeschlossen
5. Editor refreshen

### 4.2 InfluxDB Connection konfigurieren

**Admin Token holen:**
```bash
sudo cat ./influxdb/tokens/admin.token | jq -r '.token'
# Kopiere das Token: apiv3_...
```

**Im Node-RED:**
1. Ziehe "influxdb out" Node in den Flow
2. Doppelklick auf den Node
3. Bei "Server": Pencil-Icon (neuer Server)
4. Konfiguration:
   - Version: `2.0` (InfluxDB 3 nutzt v2 API Compatibility)
   - URL: `http://influxdb:8181`
   - Token: `[Dein Admin Token]`
   - Organization: ` ` (leer lassen)
   - Default Bucket: `mintfv`
5. "Add" → "Done"

### 4.3 Test-Flow erstellen

**Flow 1: Daten schreiben**

```
[Inject] → [Function] → [InfluxDB Out]
```

**Inject Node:**
- Repeat: interval 10 seconds

**Function Node:**
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
1. "Deploy" klicken
2. Inject-Button drücken
3. Debug-Panel prüfen

**Daten verifizieren:**
```bash
# Admin Token holen
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# Query ausführen
curl -fsS --max-time 10 \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -G "https://mintfv.peddy.net/influxdb/query" \
  --data-urlencode "db=mintfv" \
  --data-urlencode "q=SELECT * FROM sensors ORDER BY time DESC LIMIT 5"
```

## 📈 Schritt 5: Dashboard installieren (Optional)

```bash
# Im Node-RED UI: Manage palette → Install
node-red-dashboard
```

**Dashboard UI Pfad in settings.js** (nach httpNodeRoot):

```javascript
httpNodeRoot: '/nodered',

// Dashboard UI
ui: { path: "/nodered/ui" },
```

Dashboard erreichbar unter: https://mintfv.peddy.net/nodered/ui

## ✅ Installations-Checkliste

Führe folgende Tests durch:

### Test 1: HTTPS Zugriff
```bash
curl -fsS https://mintfv.peddy.net/nodered/ | grep "Node-RED"
# Erwartung: HTML mit "Node-RED"
```

### Test 2: Container Healthcheck
```bash
docker compose ps nodered
# Erwartung: STATUS = "Up X seconds (healthy)"
```

### Test 3: Login funktioniert
- Browser: https://mintfv.peddy.net/nodered/
- Login mit admin / [dein Passwort]
- Erwartung: Flow Editor öffnet sich

### Test 4: InfluxDB Connection
- Deploy einen Test-Flow (siehe oben)
- Daten sollten in InfluxDB ankommen
- Mit curl Query verifizieren

### Test 5: WebSocket funktioniert
- Im Editor: Flow ändern und speichern
- Erwartung: Keine "Lost connection to server" Fehler

## 🐛 Troubleshooting

### Problem: Login-Screen erscheint nicht

**Lösung:**
```bash
# settings.js prüfen
grep -A8 "adminAuth:" ./nodered/data/settings.js

# Syntax-Check
docker compose exec nodered node -c "require('/data/settings.js')"

# Logs prüfen
docker compose logs nodered | grep -i auth
```

### Problem: "Lost connection to server"

**Ursache:** WebSocket Problem

**Lösung:**
```bash
# nginx config prüfen
grep -A5 "location /nodered/" ./nginx/conf/ssl.conf | grep -i upgrade

# Sollte enthalten:
# proxy_set_header Upgrade $http_upgrade;
# proxy_set_header Connection "upgrade";
```

### Problem: InfluxDB Node nicht gefunden

**Lösung:**
```bash
# Im Container installieren
docker compose exec nodered npm install node-red-contrib-influxdb

# Container neu starten
docker compose restart nodered
```

### Problem: Credentials nicht lesbar

**Ursache:** credentialSecret geändert nach erstem Deploy

**Lösung:**
```bash
# Backup erstellen
cp ./nodered/data/flows_cred.json ./nodered/data/flows_cred.json.backup

# Credentials löschen (müssen neu eingegeben werden!)
rm ./nodered/data/flows_cred.json

# Container neu starten
docker compose restart nodered
```

## 📚 Nächste Schritte

1. **Backup-Routine einrichten** (siehe [BACKUP.md](BACKUP.md))
2. **Mosquitto MQTT integrieren** (wenn verfügbar)
3. **Weitere Nodes installieren**:
   - `node-red-contrib-cron-plus` - Scheduler
   - `node-red-node-email` - Email senden
   - `node-red-contrib-telegrambot` - Telegram Bot
4. **Flows organisieren** mit Tabs und Gruppen
5. **Monitoring in Grafana einrichten**

## 📖 Weitere Dokumentation

- Vollständige Doku: [NODERED.md](NODERED.md)
- InfluxDB Setup: [INFLUXDB.md](INFLUXDB.md)
- Backup Strategy: [BACKUP.md](BACKUP.md)

---

**Status:** Stand 27. Dezember 2025
- Node-RED v4.1.2
- Node.js v20.19.6
- InfluxDB 3.8 Core Integration
