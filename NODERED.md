# Node-RED Setup und Konfiguration

## Überblick

Node-RED ist ein flow-basiertes Development Tool für visuelle Programmierung, besonders geeignet für IoT und Automation. In diesem Setup läuft Node-RED hinter nginx mit SSL und ist über `/nodered/` erreichbar.

**Wichtig: Node-RED ist NICHT multi-tenant fähig!** Es gibt nur einen globalen Admin-Zugang. Alle Benutzer mit Login-Zugang haben vollen Zugriff auf alle Flows und Konfigurationen.

## Service Details

- **Docker Image**: `nodered/node-red:latest`
- **Container Name**: `mintfv-nodered`
- **User/Group**: `2004:2100`
- **Interner Port**: 1880
- **Externer Zugriff**: `https://mintfv.peddy.net/nodered/`
- **Data Directory**: `./nodered/data/`
- **Healthcheck**: HTTP GET zu `/`

## Ersteinrichtung

### 1. Directories erstellen und Permissions setzen

```bash
# Verzeichnisse anlegen
mkdir -p ./nodered/data

# Permissions setzen (UID 2004, GID 2100)
sudo chown -R 2004:2100 ./nodered/data
sudo chmod -R 750 ./nodered/data
```

### 2. Container starten

```bash
# Mit mintfv.sh
./mintfv.sh start

# Oder manuell
docker compose up -d nodered
```

### 3. Node-RED öffnen

Browser: `https://mintfv.peddy.net/nodered/`

**Beim ersten Start**:
- Node-RED läuft **ohne Authentifizierung**!
- Du siehst direkt den Flow-Editor
- **Wichtig**: Sofort Passwort-Authentifizierung aktivieren!

## Passwort-Schutz aktivieren

### Schritt 1: Passwort-Hash generieren

```bash
# Im Container
docker compose exec nodered node-red admin hash-pw

# Gib dein gewünschtes Passwort ein
# Beispiel-Ausgabe: $2b$08$abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJ
```

**Speichere den Hash** - du brauchst ihn für die Konfiguration!

### Schritt 2: settings.js bearbeiten

```bash
# Container stoppen
docker compose stop nodered

# settings.js editieren
nano ./nodered/data/settings.js
```

### Schritt 3: Authentifizierung konfigurieren

Suche nach dem `adminAuth` Block (ca. Zeile 100-150) und ersetze:

```javascript
// VORHER (auskommentiert):
//adminAuth: {
//    type: "credentials",
//    users: [{
//        username: "admin",
//        password: "$2a$08$...",
//        permissions: "*"
//    }]
//},

// NACHHER (aktiviert mit deinem Hash):
adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2b$08$abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJ",
        permissions: "*"
    }]
},
```

**Wichtige Parameter:**
- `username`: Dein Login-Name (z.B. "admin")
- `password`: Der Hash aus Schritt 1 (NICHT das Klartext-Passwort!)
- `permissions`: `"*"` = voller Zugriff, `"read"` = nur Lesezugriff

### Schritt 4: Container neu starten

```bash
docker compose start nodered

# Logs prüfen
docker compose logs -f nodered
```

### Schritt 5: Login testen

1. Browser: `https://mintfv.peddy.net/nodered/`
2. Login-Screen sollte erscheinen
3. Anmelden mit deinen Credentials

## Erweiterte Konfiguration

### httpNodeRoot anpassen für Reverse Proxy

In `./nodered/data/settings.js`:

```javascript
// Für korrekte Pfade hinter nginx Reverse Proxy
httpNodeRoot: '/nodered',
httpAdminRoot: '/nodered',

// Optional: Static Content
//httpStatic: '/data/static/',

// UI Pfad (falls Dashboard genutzt wird)
ui: { path: "/nodered/ui" },
```

### Mehrere Benutzer anlegen

```javascript
adminAuth: {
    type: "credentials",
    users: [
        {
            username: "admin",
            password: "$2b$08$HASH_1",
            permissions: "*"
        },
        {
            username: "readonly",
            password: "$2b$08$HASH_2",
            permissions: "read"
        }
    ]
},
```

**Limitierung**: Alle Benutzer sehen alle Flows! Es gibt keine User-spezifische Isolation.

### Session Timeout anpassen

```javascript
adminAuth: {
    type: "credentials",
    users: [...],
    default: {
        permissions: "read"  // Nicht-authentifizierte Benutzer
    },
    sessionExpiryTime: 86400,  // 24 Stunden (Standard: 7 Tage)
},
```

## Multi-Tenancy: Nein, nicht möglich!

**Antwort auf die Frage: Ist Node-RED multi-tenant fähig?**

❌ **Nein, Node-RED ist NICHT multi-tenant fähig.**

### Limitierungen:

1. **Gemeinsamer Workspace**: Alle Benutzer sehen dieselben Flows
2. **Keine Isolation**: Kein Konzept von "persönlichen" oder "privaten" Flows
3. **Global Shared Context**: Alle Flows teilen sich Context/Variables
4. **Kein RBAC**: Nur "Admin" oder "Read-Only" Rechte, keine granularen Permissions
5. **Single Instance**: Eine Node-RED Instanz = ein Workspace

### Workarounds für Pseudo-Multi-Tenancy:

#### Option 1: Separate Container-Instanzen

```yaml
# docker-compose.yaml
nodered-tenant1:
  image: nodered/node-red:latest
  container_name: mintfv-nodered-tenant1
  user: "2004:2100"
  volumes:
    - ./nodered/tenant1:/data:rw
  # ... location /nodered-tenant1/

nodered-tenant2:
  image: nodered/node-red:latest
  container_name: mintfv-nodered-tenant2
  user: "2005:2100"
  volumes:
    - ./nodered/tenant2:/data:rw
  # ... location /nodered-tenant2/
```

**Nachteile**: 
- Hoher Ressourcen-Overhead (RAM, CPU)
- Management-Aufwand (Updates, Backups)
- Komplexe nginx Konfiguration

#### Option 2: Flow-basierte Organisation

Organisiere Flows mit Präfixen oder Tabs:
- Tab: "Tenant A - Sensors"
- Tab: "Tenant B - Automation"

**Nachteile**:
- Rein organisatorisch, keine echte Isolation
- Alle User sehen alles
- Versehentliche Änderungen möglich

#### Option 3: External Auth Proxy (z.B. Authelia)

Nutze einen Auth-Proxy vor Node-RED:
```
nginx → Authelia (LDAP/SAML) → Node-RED
```

**Nachteile**:
- Nur Login-Isolation, keine Flow-Isolation
- Alle authentifizierten User haben gleiche Rechte in Node-RED
- Zusätzliche Komplexität

### Empfehlung:

Für echte Multi-Tenancy: **Nutze separate Node-RED Instanzen pro Tenant/Team**.

Für kleine Teams ohne strikte Isolation: **Organisiere Flows mit klarer Namenskonvention und setze auf Vertrauen + Code Reviews**.

## InfluxDB Integration

### Node installieren

1. Im Node-RED UI: Menu → Manage palette → Install
2. Suche: `node-red-contrib-influxdb`
3. Install klicken

### InfluxDB Node konfigurieren

**Connection Settings:**
```
Version: 2.0 (InfluxDB 3 nutzt v2 API Compatibility)
URL: http://influxdb:8181
Token: [Dein Admin Token aus ./influxdb/tokens/admin.token]
Organization: - (leer lassen)
Bucket: mintfv (= Database Name in InfluxDB 3)
```

**Admin Token holen:**
```bash
sudo cat ./influxdb/tokens/admin.token | jq -r '.token'
```

### Beispiel Flow: Daten schreiben

```json
[
    {
        "id": "influx_write",
        "type": "influxdb out",
        "influxdb": "YOUR_INFLUXDB_CONFIG_ID",
        "name": "Write to InfluxDB",
        "measurement": "sensors",
        "precision": "ms",
        "retentionPolicy": "",
        "x": 500,
        "y": 100,
        "wires": []
    }
]
```

**Input Format:**
```javascript
msg.payload = {
    temperature: 22.5,
    humidity: 55,
    location: "livingroom"
};
```

### Beispiel Flow: Daten lesen

```json
[
    {
        "id": "influx_query",
        "type": "influxdb in",
        "influxdb": "YOUR_INFLUXDB_CONFIG_ID",
        "name": "Query InfluxDB",
        "query": "SELECT * FROM sensors WHERE time > now() - 1h",
        "x": 300,
        "y": 200,
        "wires": [["debug_node"]]
    }
]
```

## Wichtige Nodes installieren

### Empfohlene Nodes für IoT/Automation:

```bash
# Im UI: Menu → Manage palette → Install
node-red-contrib-influxdb       # InfluxDB Integration
node-red-dashboard              # Web Dashboard UI
node-red-node-email             # Email senden
node-red-contrib-telegrambot    # Telegram Bot
node-red-contrib-cron-plus      # Cron Scheduler
```

## Backup und Restore

### Backup erstellen

```bash
# Flows sichern
sudo tar -czf nodered-backup-$(date +%Y%m%d).tar.gz \
  -C ./nodered/data \
  flows.json \
  flows_cred.json \
  settings.js \
  package.json

# Oder einfach kopieren
sudo cp -r ./nodered/data ./backups/nodered-$(date +%Y%m%d)
```

### Restore

```bash
# Container stoppen
docker compose stop nodered

# Backup wiederherstellen
sudo rm -rf ./nodered/data/*
sudo tar -xzf nodered-backup-20251227.tar.gz -C ./nodered/data/

# Permissions korrigieren
sudo chown -R 2004:2100 ./nodered/data
sudo chmod -R 750 ./nodered/data

# Container starten
docker compose start nodered
```

## Troubleshooting

### Problem: "EACCES: permission denied"

```bash
# Permissions prüfen
ls -la ./nodered/data

# Korrigieren
sudo chown -R 2004:2100 ./nodered/data
sudo chmod -R 750 ./nodered/data
```

### Problem: Login funktioniert nicht

1. **Hash prüfen**: Passwort-Hash muss mit `$2b$` oder `$2a$` beginnen
2. **JSON Syntax**: Kommafehler in settings.js?
3. **Logs prüfen**: `docker compose logs nodered | grep -i auth`

```bash
# settings.js Syntax testen
docker compose exec nodered node -c "require('/data/settings.js')"
```

### Problem: Reverse Proxy funktioniert nicht

**Symptom**: Node-RED lädt, aber Flows werden nicht angezeigt

**Lösung**: `httpNodeRoot` und `httpAdminRoot` in settings.js setzen:

```javascript
httpNodeRoot: '/nodered',
httpAdminRoot: '/nodered',
```

Container neu starten: `docker compose restart nodered`

### Problem: WebSocket Verbindung schlägt fehl

**Symptom**: "Lost connection to server" im Browser

**Prüfen**:
```bash
# nginx Konfiguration testen
docker compose exec nginx nginx -t

# WebSocket Headers prüfen
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  https://mintfv.peddy.net/nodered/
```

## Security Best Practices

### 1. **Immer Authentifizierung aktivieren**

Nie Node-RED ohne Login laufen lassen!

### 2. **Starke Passwörter**

```bash
# Mindestens 16 Zeichen
openssl rand -base64 24
```

### 3. **Session Timeout**

```javascript
sessionExpiryTime: 3600,  // 1 Stunde statt 7 Tage
```

### 4. **Read-Only User für Monitoring**

```javascript
users: [
    {
        username: "admin",
        password: "$2b$08$ADMIN_HASH",
        permissions: "*"
    },
    {
        username: "monitor",
        password: "$2b$08$READONLY_HASH",
        permissions: "read"
    }
]
```

### 5. **HTTPS Only**

Bereits durch nginx SSL erzwungen ✅

### 6. **Rate Limiting**

Bereits in nginx konfiguriert:
- 30 req/s normal
- Burst 50
- Connection Limit 50

### 7. **Credentials verschlüsseln**

In `settings.js`:

```javascript
credentialSecret: "your-secret-key-min-32-chars-recommended",
```

**Wichtig**: Einmal gesetzt, NICHT ändern - sonst sind Credentials unlesbar!

```bash
# Secret generieren
openssl rand -hex 32
```

## Monitoring

### Health Status prüfen

```bash
# Healthcheck
docker compose ps nodered

# Status API
curl -s https://mintfv.peddy.net/nodered/ | grep -i "node-red"

# Logs
docker compose logs --tail=100 -f nodered
```

### Metrics exportieren

Node-RED hat keine eingebauten Prometheus Metrics. Nutze stattdessen:

1. **Custom Function Node** mit HTTP Endpoint
2. **node-red-contrib-prometheus-exporter** (Community Node)

## Performance Tuning

### Memory Limit anpassen

In `docker-compose.yaml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'      # Erhöhen bei vielen Flows
      memory: 512M     # Erhöhen bei großen Flows
```

### Node.js Heap Size

In `docker-compose.yaml`:

```yaml
environment:
  - NODE_OPTIONS=--max-old-space-size=512
```

## Nützliche Links

- [Node-RED Dokumentation](https://nodered.org/docs/)
- [Node-RED Security](https://nodered.org/docs/user-guide/runtime/securing-node-red)
- [InfluxDB Node](https://flows.nodered.org/node/node-red-contrib-influxdb)
- [Dashboard Node](https://flows.nodered.org/node/node-red-dashboard)
- [Flow Library](https://flows.nodered.org/)

## Zusammenfassung

✅ **Was funktioniert:**
- Node-RED läuft unter UID 2004:2100
- Zugriff via HTTPS und nginx Reverse Proxy
- Passwort-Authentifizierung konfigurierbar
- InfluxDB 3 Integration möglich
- WebSocket Support für Editor

❌ **Was NICHT funktioniert:**
- Multi-Tenancy / User Isolation
- Granulare Permissions (nur Admin/ReadOnly)
- Private Flows pro User
- RBAC (Role-Based Access Control)

💡 **Für echte Multi-Tenancy**: Nutze separate Container-Instanzen pro Tenant!
