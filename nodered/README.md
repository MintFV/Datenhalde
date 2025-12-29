# Node-RED

Flow-basierte Programmierung für IoT Automation & Datenverarbeitung.

**URL:** https://mintfv.peddy.net/nodered/  
**Container:** mintfv-nodered (UID 2004:2100)  
**Port:** 1880 (intern)

---

## 🚀 Quick Start

### Status prüfen
```bash
docker compose ps nodered
docker compose logs -f nodered
```

### Zugriff
Öffne im Browser: `https://mintfv.peddy.net/nodered/`

---

## 🔐 Authentifizierung aktivieren

⚠️ **WICHTIG**: Passwort-Schutz sollte in Produktion aktiviert werden!

### 1. Passwort-Hash generieren
```bash
docker compose exec nodered npx node-red admin hash-pw
# Gib dein Passwort ein, kopiere den Hash
```

### 2. In .env eintragen
```bash
vi .env
```

Füge hinzu:
```bash
NODE_RED_ADMIN_USER=admin
NODE_RED_ADMIN_PASSWORD_HASH='$2y$08$...'  # Dein generierter Hash
```

### 3. Settings aktivieren
```bash
vi ./nodered/data/settings.js
```

Aktiviere (ca. Zeile 100):
```javascript
adminAuth: {
    type: "credentials",
    users: [{
        username: process.env.NODE_RED_ADMIN_USER || "admin",
        password: process.env.NODE_RED_ADMIN_PASSWORD_HASH,
        permissions: "*"
    }]
}
```

### 4. Container neu starten
```bash
docker compose restart nodered
```

---

## 📊 InfluxDB Integration

### Node installieren
```
Menü (☰) → Manage Palette → Install → node-red-contrib-influxdb
```

### InfluxDB Node konfigurieren
```
URL: http://influxdb:8181
Organization: InfluxDB
Token: [siehe ./influxdb/tokens/admin.token]
Bucket: mintfv
```

### Test-Flow
```json
[inject] → [function] → [influxdb out]

// Function Node:
msg.payload = {
    temperature: 23.5,
    humidity: 45.2,
    location: "room-01"
};
return msg;
```

---

## 🔗 MQTT Integration

### MQTT Broker konfigurieren
```
Server: mosquitto:1883 (intern) oder mintfv.peddy.net:1883 (extern)
Username: tenant-a-nodered
Password: nodered-a
```

### Test-Flow: MQTT → InfluxDB
```
[mqtt in] → [json] → [function] → [influxdb out]

// MQTT In Config:
Topic: tenant/tenant-a/sensor01/+
QoS: 1

// Function Node:
msg.payload = {
    sensor_id: "sensor01",
    temperature: msg.payload.temperature,
    timestamp: Date.now()
};
return msg;
```

---

## 📝 Wichtige Einstellungen

### Credential Secret
⚠️ **NIEMALS ändern** nach dem ersten Start! Flows mit gespeicherten Credentials werden sonst unbrauchbar.

```bash
# In .env
NODE_RED_CREDENTIAL_SECRET='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

### Context Storage
Für persistente Variablen zwischen Neustarts:

```javascript
// In settings.js
contextStorage: {
    default: "file",
    file: {
        module: "localfilesystem"
    }
}
```

---

## 🧪 Debugging

### Debug-Node verwenden
1. Drag & Drop "debug" Node in Flow
2. Verbinde mit Output
3. Öffne Debug-Panel (rechts)
4. Deploy & Teste

### Logs anzeigen
```bash
docker compose logs -f nodered
```

### Container Console
```bash
docker compose exec nodered sh
```

---

## 💾 Backup & Restore

### Flows exportieren
```
Menü → Export → Alle Flows
```

### Flows importieren
```
Menü → Import → Clipboard
```

### Data-Verzeichnis sichern
```bash
tar -czf nodered-backup-$(date +%Y%m%d).tar.gz ./nodered/data/
```

---

## 📦 Nützliche Nodes

### Vorinstalliert
- `mqtt` - MQTT Broker Connection
- `http` - HTTP Request/Response
- `json` - JSON Parser
- `function` - JavaScript Code

### Empfohlen
```
node-red-contrib-influxdb    # InfluxDB Integration
node-red-dashboard           # UI Dashboard
node-red-node-email          # Email-Benachrichtigungen
node-red-contrib-telegrambot # Telegram Bot
```

Installation:
```
Menü → Manage Palette → Install → [node-name]
```

---

## ⚠️ Troubleshooting

### Problem: Node-RED nicht erreichbar
```bash
# Container-Status prüfen
docker compose ps nodered

# Logs prüfen
docker compose logs nodered | tail -20

# Neu starten
docker compose restart nodered
```

### Problem: Login funktioniert nicht
```bash
# Hash korrekt generiert?
docker compose exec nodered npx node-red admin hash-pw

# settings.js Syntax prüfen
docker compose exec nodered node -c "require('./data/settings.js')"

# Container neu starten
docker compose restart nodered
```

### Problem: Flows werden nicht gespeichert
```bash
# Permissions prüfen
ls -la ./nodered/data/flows*.json

# Sollte UID 2004 gehören
sudo chown -R 2004:2100 ./nodered/data/
```

---

## 📚 Weitere Informationen

- **Config:** `./nodered/data/settings.js`
- **Flows:** `./nodered/data/flows.json` (git-ignored)
- **Packages:** `./nodered/data/package.json`
- **Docs:** [Node-RED Docs](https://nodered.org/docs/)
- **InfluxDB Integration:** [../influxdb/README.md](../influxdb/README.md)
- **MQTT Integration:** [../mosquitto/README.md](../mosquitto/README.md)
