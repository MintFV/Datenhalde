# InfluxDB 3 Core Setup und Konfiguration

## Übersicht

InfluxDB 3 Core ist die neueste Generation der InfluxDB Time-Series Datenbank mit Apache Arrow und DataFusion SQL Engine.

**Version**: 3.8.0 (3-core)

## Zugriff

### Web UI
ℹ️ **InfluxDB 3 Core hat keine eingebaute Web-UI mehr.** Verwende stattdessen:
- InfluxDB 3 Explorer (separates Tool)
- Grafana für Visualisierung
- `influxdb3` CLI für Verwaltung

### API Endpoints
Über nginx Reverse Proxy erreichbar:

- **v1 API (InfluxQL)**: `https://mintfv.peddy.net/influxdb/query`
- **v2 API (Compatibility)**: `https://mintfv.peddy.net/influxdb/api/v2/`
- **v3 API (Native)**: `https://mintfv.peddy.net/influxdb/api/v3/`

## Admin Token Management

### Admin Token erstellen

Das Admin Token wird beim ersten Start von InfluxDB 3 Core aus einer JSON-Datei geladen.

**Schritt 1: Token generieren**
```bash
# Sicheren Token generieren (min. 128 Bit Entropie)
TOKEN="apiv3_$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-32)"
echo "Generierter Token: $TOKEN"
```

**Schritt 2: Token-Datei erstellen**
```bash
# Ablaufdatum berechnen (10 Jahre in Millisekunden)
EXPIRY=$(($(date +%s) * 1000 + 315360000000))

# JSON-Datei erstellen
sudo bash -c "cat > ./influxdb/tokens/admin.token << EOF
{
  \"token\": \"$TOKEN\",
  \"name\": \"_admin\",
  \"expiry_millis\": $EXPIRY
}
EOF
"

# Sichere Permissions setzen (WICHTIG!)
sudo chown 2005:2100 ./influxdb/tokens/admin.token
sudo chmod 600 ./influxdb/tokens/admin.token
```

**Schritt 3: Token sicher speichern**
```bash
# Token in Passwort-Manager oder verschlüsselter Datei speichern!
echo "$TOKEN" | gpg -e -r your@email.com > admin-token.gpg
```

### Bestehendes Token auslesen

```bash
# Token aus Datei lesen
sudo cat ./influxdb/tokens/admin.token | jq -r '.token'
```

### Token verwenden

Das Admin Token wird für **alle** API-Operationen benötigt:

```bash
# Token als Umgebungsvariable setzen
export INFLUXDB3_AUTH_TOKEN="apiv3_..."

# Oder direkt in Befehlen verwenden
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="apiv3_..." influxdb \
  influxdb3 COMMAND
```

## Datenbank erstellen

### Neue Datenbank anlegen

```bash
# 1. Admin Token als Variable setzen (aus admin.token Datei)
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# 2. Datenbank erstellen
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 create database DATENBANKNAME

# Optional: Mit Retention Policy
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 create database DATENBANKNAME --retention-period "30d"
```

### Datenbanken auflisten

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show databases
```

### Datenbank löschen

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 delete database DATENBANKNAME
```

## Daten schreiben und abfragen

### Test-Daten schreiben

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# Line Protocol schreiben
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 write --database DATENBANKNAME \
  "temperature,location=office value=23.5"

# Mehrere Datenpunkte
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 write --database DATENBANKNAME \
  "temperature,location=office value=23.5
temperature,location=garage value=18.2
humidity,location=office value=65.0"
```

### Daten abfragen (SQL)

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# SQL-Query
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 query --database DATENBANKNAME \
  "SELECT * FROM temperature ORDER BY time DESC LIMIT 10"
```

### Daten abfragen (InfluxQL - v1 API)

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# Via Container
docker compose exec -T influxdb \
  curl -s -H "Authorization: Token $ADMIN_TOKEN" \
  --get "http://localhost:8181/query" \
  --data-urlencode "db=DATENBANKNAME" \
  --data-urlencode "q=SELECT * FROM temperature"

# Via HTTPS (extern)
curl -s -H "Authorization: Token $ADMIN_TOKEN" \
  --get "https://mintfv.peddy.net/influxdb/query" \
  --data-urlencode "db=DATENBANKNAME" \
  --data-urlencode "q=SELECT * FROM temperature"
```

## API Tests durchführen

### v1 API (InfluxQL) testen

**Schreiben:**
```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

curl -i "https://mintfv.peddy.net/influxdb/write?db=DATENBANKNAME&precision=s" \
  --header "Authorization: Bearer $ADMIN_TOKEN" \
  --header "Content-type: text/plain; charset=utf-8" \
  --data-binary 'temperature,location=bedroom value=21.5'
```

**Lesen:**
```bash
curl --get "https://mintfv.peddy.net/influxdb/query" \
  --header "Authorization: Token $ADMIN_TOKEN" \
  --data-urlencode "db=DATENBANKNAME" \
  --data-urlencode "q=SELECT * FROM temperature WHERE time > now() - 1h"
```

### v2 API (Compatibility) testen

**Schreiben:**
```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

curl -i "https://mintfv.peddy.net/influxdb/api/v2/write?bucket=DATENBANKNAME&precision=s" \
  --header "Authorization: Token $ADMIN_TOKEN" \
  --header "Content-type: text/plain; charset=utf-8" \
  --data-binary 'temperature,location=kitchen value=22.8'
```

### Healthcheck testen

```bash
# Healthcheck (benötigt KEIN Token)
curl -i https://mintfv.peddy.net/influxdb/health

# Sollte 200 OK zurückgeben
```

## Technische Details

### Container-Konfiguration

- **Image**: `influxdb:3-core` (3.8.0)
- **User ID**: 2005:2100
- **Shared GID**: 2100 (ssl-certs)
- **Interner Port**: 8181 (geändert von 8086)
- **Storage Engine**: Apache Arrow + DataFusion
- **Externer Zugriff**: Nur via nginx reverse proxy

### Verzeichnisstruktur

```
influxdb/
├── data/                   # Persistente Daten (Apache Arrow Format) [BACKUP]
│   ├── catalog/           # Catalog Dateien
│   └── wal/              # Write-Ahead Log
├── plugins/               # Python Processing Engine Plugins
└── tokens/                # Admin Token Datei [BACKUP - VERSCHLÜSSELT!]
    └── admin.token       # JSON mit Admin Token (Permissions: 600)
```

### Command-Line Optionen

```yaml
DOCKER_INFLUXDB_INIT_MODE: setup
DOCKER_INFLUXDB_INIT_USERNAME: admin
DOCKER_INFLUXDB_INIT_PASSWORD: mintfv-admin-2025
DOCKER_INFLUXDB_INIT_ORG: mintfv
DOCKER_INFLUXDB_INIT_BUCKET: sensors
DOCKER_INFLUXDB_INIT_RETENTION: 52w
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN: mintfv-super-secret-token-change-me
INFLUXD_LOG_LEVEL: info
INFLUXD_HTTP_BIND_ADDRESS: :8086
```

## Erste Schritte

```

InfluxDB 3 Core wird mit folgenden Flags gestartet:

```bash
influxdb3 serve \
  --node-id=mintfv-node-0 \
  --object-store=file \
  --data-dir=/var/lib/influxdb3/data \
  --plugin-dir=/var/lib/influxdb3/plugins \
  --http-bind=0.0.0.0:8181 \
  --disable-authz=health,ping \
  --admin-token-file=/var/lib/influxdb3/tokens/admin.token
```

**Wichtige Optionen:**
- `--disable-authz=health,ping`: Health/Ping Endpunkte ohne Auth (für Docker Healthcheck)
- `--admin-token-file`: Pfad zur Admin Token JSON-Datei
- `--object-store=file`: Lokaler File-basierter Object Store (andere: S3, MinIO)

### Healthcheck

Docker Healthcheck prüft `/health` Endpunkt alle 30 Sekunden:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f --max-time 2 http://localhost:8181/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

## Grafana Integration

### Data Source konfigurieren

**Variante 1: InfluxDB v1 (InfluxQL)**

```yaml
Type: InfluxDB
Query Language: InfluxQL
URL: http://influxdb:8181
Database: DATENBANKNAME
User: (beliebig, wird ignoriert)
Password: [ADMIN_TOKEN]
HTTP Method: GET
```

**Variante 2: InfluxDB v2 (Flux - Compatibility)**

```yaml
Type: InfluxDB
Query Language: Flux
URL: http://influxdb:8181
Organization: (optional)
Token: [ADMIN_TOKEN]
Default Bucket: DATENBANKNAME
```

**Variante 3: Flight SQL (Native InfluxDB 3)**

Benötigt zusätzliche Grafana Plugins für Apache Arrow Flight SQL.

### Test-Query in Grafana

**InfluxQL:**
```sql
SELECT mean("value") 
FROM "temperature" 
WHERE time > now() - 1h 
GROUP BY time(5m), "location"
```

**SQL:**
```sql
SELECT 
  time_bucket('5 minutes', time) AS bucket,
  location,
  AVG(value) as avg_value
FROM temperature
WHERE time > now() - INTERVAL '1 hour'
GROUP BY bucket, location
ORDER BY bucket DESC
```

## Troubleshooting

### Token-Authentifizierung schlägt fehl

**Problem:** `{"error": "the request was not authenticated"}`

**Lösung:**
1. Token-Format prüfen (muss mit `apiv3_` beginnen)
2. Token-Datei Permissions prüfen: `600` und Owner `2005:2100`
3. Token-Datei JSON-Format validieren:
   ```bash
   sudo cat ./influxdb/tokens/admin.token | jq .
   ```
4. Container neu starten:
   ```bash
   docker compose restart influxdb
   ```

### Healthcheck schlägt fehl

**Problem:** Container bleibt "unhealthy"

**Lösung:**
1. Logs prüfen:
   ```bash
   docker compose logs influxdb --tail=50
   ```
2. Health-Endpoint manuell testen:
   ```bash
   docker compose exec influxdb curl -f http://localhost:8181/health
   ```
3. Prüfe ob `--disable-authz=health,ping` gesetzt ist

### Datenbank existiert nicht

**Problem:** `{"error": "database not found"}`

**Lösung:**
```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# Alle Datenbanken auflisten
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show databases

# Falls nicht vorhanden, erstellen
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 create database DATENBANKNAME
```

### Permission Denied Fehler

**Problem:** `Permission denied` beim Container-Start

**Lösung:**
```bash
# Korrekte Permissions setzen
sudo chown -R 2005:2100 ./influxdb/data ./influxdb/tokens ./influxdb/plugins
sudo chmod 750 ./influxdb/data ./influxdb/plugins
sudo chmod 600 ./influxdb/tokens/admin.token
```

### Container startet nicht

**Problem:** InfluxDB Container exitiert mit Fehler

**Lösung:**
1. Logs prüfen:
   ```bash
   docker compose logs influxdb
   ```
2. Token-Datei Format validieren
3. Data Directory Permissions prüfen
4. Bei Bedarf Data Directory leeren (ACHTUNG: Datenverlust!):
   ```bash
   docker compose stop influxdb
   sudo rm -rf ./influxdb/data/*
   docker compose up -d influxdb
   ```

## Backup & Restore

### Backup erstellen

```bash
# 1. Container stoppen (für konsistenten Backup)
docker compose stop influxdb

# 2. Backup erstellen
sudo tar -czf influxdb3-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  influxdb/data/ \
  influxdb/tokens/

# 3. Container wieder starten
docker compose start influxdb

# 4. Backup verschlüsseln (empfohlen!)
gpg -e -r your@email.com influxdb3-backup-*.tar.gz
```

### Restore durchführen

```bash
# 1. Container stoppen
docker compose stop influxdb

# 2. Alte Daten löschen
sudo rm -rf ./influxdb/data/*
sudo rm -f ./influxdb/tokens/admin.token

# 3. Backup entpacken
sudo tar -xzf influxdb3-backup-TIMESTAMP.tar.gz

# 4. Permissions korrigieren
sudo chown -R 2005:2100 ./influxdb/data ./influxdb/tokens
sudo chmod 750 ./influxdb/data
sudo chmod 600 ./influxdb/tokens/admin.token

# 5. Container starten
docker compose start influxdb
```

### Automated Backup

Siehe [BACKUP.md](BACKUP.md) für automatisierte Backup-Strategien mit:
- Cron-Jobs
- Restic
- rsync
- Remote-Backups

## Performance Tuning

### Write Performance

```bash
# Batch-Writes verwenden (100-5000 Punkte pro Request)
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 write --database DATENBANKNAME < large-dataset.lp
```

### Query Performance

```sql
-- Indexes nutzen (time + tags sind automatisch indexiert)
SELECT * FROM temperature 
WHERE time > now() - INTERVAL '1 hour' 
  AND location = 'office';

-- LIMIT verwenden für große Datasets
SELECT * FROM temperature 
ORDER BY time DESC 
LIMIT 1000;

-- Aggregation für große Zeiträume
SELECT 
  time_bucket('1 hour', time) AS hour,
  AVG(value) as avg_value
FROM temperature
WHERE time > now() - INTERVAL '7 days'
GROUP BY hour;
```

## Monitoring

### Systemmetriken abfragen

```bash
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# System Summary
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show system summary

# Detaillierte Tabellen-Infos
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show system table-list
```

### Container Logs

```bash
# Live Logs
docker compose logs -f influxdb

# Letzte 100 Zeilen
docker compose logs influxdb --tail=100

# Logs mit Zeitstempel
docker compose logs influxdb --timestamps
```

### Health Status

```bash
# Container Health
docker compose ps influxdb

# HTTP Health Endpoint
curl -i https://mintfv.peddy.net/influxdb/health

# Ping Endpoint
curl -i https://mintfv.peddy.net/influxdb/ping
```

## Sicherheit

### Best Practices

1. **Token-Sicherheit**
   - Niemals Tokens in Git committen
   - Token regelmäßig rotieren (z.B. alle 6 Monate)
   - Separate Tokens für verschiedene Applikationen
   - Verschlüsseltes Backup der Token-Datei

2. **Network-Sicherheit**
   - InfluxDB nur via nginx erreichbar (kein direkter Port-Zugriff)
   - HTTPS-only (HTTP → HTTPS Redirect)
   - Rate Limiting in nginx konfigurieren

3. **File Permissions**
   ```bash
   # Minimale Permissions
   chmod 600 ./influxdb/tokens/admin.token  # rw-------
   chmod 750 ./influxdb/data                # rwxr-x---
   chmod 750 ./influxdb/plugins             # rwxr-x---
   ```

4. **Audit Logging**
   - Alle API-Zugriffe werden in nginx Logs erfasst
   - Siehe `/var/log/nginx/access.log` für HTTP-Requests

## Ressourcen

### Offizielle Dokumentation

- [InfluxDB 3 Core Docs](https://docs.influxdata.com/influxdb3/core/)
- [InfluxDB 3 API Reference](https://docs.influxdata.com/influxdb3/core/api/v3/)
- [SQL Reference](https://docs.influxdata.com/influxdb3/core/reference/sql/)
- [InfluxQL Reference](https://docs.influxdata.com/influxdb3/core/reference/influxql/)

### Client Libraries

- [Python](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/python/)
- [Go](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/go/)
- [JavaScript/Node.js](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/javascript/)
- [Java](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/java/)

### Community

- [InfluxDB Discord](https://discord.gg/9zaNCW2PRT) (Preferred)
- [InfluxData Community](https://community.influxdata.com/)
- [GitHub Issues](https://github.com/influxdata/influxdb/issues)

## Changelog

### InfluxDB 3.8.0 (Dezember 2025)
- ✅ Apache Arrow + DataFusion SQL Engine
- ✅ Port 8181 (Standard für InfluxDB 3 Core)
- ✅ Admin Token System (JSON-basiert)
- ✅ Healthcheck ohne Auth (`--disable-authz=health,ping`)
- ✅ v1/v2 API Compatibility
- ℹ️ Keine Web-UI (nutze InfluxDB 3 Explorer oder Grafana)
```

### Via API (curl)

```bash
# Token aus InfluxDB UI kopieren
TOKEN="dein-api-token-hier"

# Datenpunkt schreiben
curl -XPOST "https://mintfv.peddy.net/influxdb/api/v2/write?org=mintfv&bucket=sensors" \
  --header "Authorization: Token ${TOKEN}" \
  --data-raw "temperature,location=room1 value=22.5"
```

### Via Node-RED (später)

Node-RED wird InfluxDB-Nodes nutzen:
- `influxdb-out` - Daten schreiben
- `influxdb-in` - Daten lesen

## Flux Query Beispiele

### Letzte Werte abrufen

```flux
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "temperature")
  |> last()
```

### Durchschnitt berechnen

```flux
from(bucket: "sensors")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "temperature")
  |> filter(fn: (r) => r.location == "room1")
  |> mean()
```

### Gruppieren nach Zeit (Aggregation)

```flux
from(bucket: "sensors")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "temperature")
  |> aggregateWindow(every: 1h, fn: mean)
```

## Security

### Passwörter ändern

**Via Web UI** (siehe oben unter "Erste Schritte")

**Via docker-compose.yaml** (für neue Container):

1. Bearbeite `docker-compose.yaml`:
   ```yaml
   environment:
     - DOCKER_INFLUXDB_INIT_PASSWORD=<dein-neues-passwort>
     - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=<dein-neues-token>
   ```
   
2. ⚠️ **Niemals** diese Secrets in Git committen!
3. Erwäge die Nutzung von Docker Secrets oder `.env` Datei

**Empfohlen: .env Datei** (nicht in Git!)

1. Erstelle `.env`:
   ```bash
   INFLUXDB_ADMIN_PASSWORD=sicheres-passwort-hier
   INFLUXDB_ADMIN_TOKEN=sehr-langer-sicherer-token
   ```

2. Update `docker-compose.yaml`:
   ```yaml
   environment:
     - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUXDB_ADMIN_PASSWORD}
     - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUXDB_ADMIN_TOKEN}
   ```

3. Füge `.env` zu `.gitignore` hinzu

### Token Management

- **All Access Token**: Volle Rechte (nur für Admin)
- **Read/Write Token**: Begrenzte Rechte für bestimmte Buckets
- **Read Only Token**: Nur Lesezugriff

Best Practice:
- Node-RED: Read/Write Token für `sensors` Bucket
- Grafana: Read Only Token
- Externe APIs: Custom Tokens mit minimalen Rechten

### Zusätzliche Security Features

InfluxDB Container läuft mit Security Hardening:
- Read-only Filesystem
- Dropped Capabilities (nur CHOWN, SETGID, SETUID, DAC_OVERRIDE)
- No New Privileges
- Resource Limits (512M RAM, 1.0 CPU)
- Alle Logs nach STDOUT/STDERR

## nginx Reverse Proxy

Konfiguration in `nginx/conf/ssl.conf`:

```nginx
location /influxdb/ {
    proxy_pass http://influxdb:8086/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # HTTP 1.1 für API
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    
    # Buffering aus für API
    proxy_buffering off;
    proxy_request_buffering off;
    
    # Timeouts für lange Queries
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;
}
```

## Troubleshooting

### InfluxDB startet nicht

```bash
# Logs prüfen
./mintfv.sh logs influxdb

# Status prüfen
docker compose ps influxdb

# Container neu starten
docker compose restart influxdb
```

### "already initialized" Fehler

Wenn Container neu erstellt wird, aber Daten existieren:

```bash
# Entweder: Daten löschen (ACHTUNG!)
docker compose down influxdb
sudo rm -rf ./influxdb/data/*
docker compose up -d influxdb

# Oder: INIT_MODE entfernen
# docker-compose.yaml: DOCKER_INFLUXDB_INIT_MODE entfernen
```

### UI nicht erreichbar

```bash
# nginx-Config prüfen
docker compose exec nginx nginx -T | grep influxdb

# nginx neu laden
docker compose exec nginx nginx -s reload

# Direct access testen
docker compose exec influxdb curl -I http://localhost:8086/health
```

### Permissions-Fehler

```bash
# Ownership prüfen
ls -la ./influxdb/data/

# Falls nötig: Korrigieren
sudo chown -R 2005:2100 ./influxdb/data/ ./influxdb/config/
sudo chmod 750 ./influxdb/data/ ./influxdb/config/
```

### Queries zu langsam

```bash
# Resource Limits erhöhen in config.yaml
services:
  influxdb:
    memory_limit: 1G
    cpu_limit: 2.0

# Container neu starten
./mintfv.sh restart
```

## Backup

Wichtige Dateien für Backup:

```bash
# Backup erstellen
./backup.sh create

# Oder manuell
rsync -av --delete \
  ./influxdb/data/ \
  /backup/mintfv/influxdb/data/

rsync -av --delete \
  ./influxdb/config/ \
  /backup/mintfv/influxdb/config/
```

### Backup & Restore mit influx CLI

**Backup erstellen:**

```bash
# Bucket backup
docker compose exec influxdb influx backup /tmp/backup \
  --org mintfv \
  --bucket sensors \
  --token <dein-token>

# Backup rauskopieren
docker compose cp influxdb:/tmp/backup ./backups/influxdb-$(date +%Y%m%d)/
```

**Restore:**

```bash
# Backup reinkopieren
docker compose cp ./backups/influxdb-20251226/ influxdb:/tmp/restore/

# Restore durchführen
docker compose exec influxdb influx restore /tmp/restore \
  --org mintfv \
  --bucket sensors \
  --token <dein-token>
```

Details: [BACKUP.md](BACKUP.md)

## Performance Tuning

### Resource Limits anpassen

In `config.yaml`:

```yaml
services:
  influxdb:
    memory_limit: 1G      # Mehr RAM für große Datasets
    cpu_limit: 2.0        # Mehr CPU für komplexe Queries
```

Nach Änderung:
```bash
./mintfv.sh restart
```

### Retention Policies

Alte Daten automatisch löschen:

1. **Load Data** → **Buckets**
2. Bucket auswählen → **Edit**
3. **Delete Data**:
   - Older than: z.B. `30d`, `90d`, `1y`
   - Oder: **Never** (unendlich)

### Downsampling

Für lange Zeiträume aggregierte Daten speichern:

```flux
// Task erstellen: Stündliche Aggregation
option task = {name: "downsample-hourly", every: 1h}

from(bucket: "sensors")
  |> range(start: -2h)
  |> filter(fn: (r) => r._measurement == "temperature")
  |> aggregateWindow(every: 1h, fn: mean)
  |> to(bucket: "sensors-hourly")
```

## CLI Befehle

Wichtige `influx` CLI Befehle:

```bash
# Login
docker compose exec influxdb influx auth list

# Buckets auflisten
docker compose exec influxdb influx bucket list

# Token erstellen
docker compose exec influxdb influx auth create \
  --org mintfv \
  --read-buckets \
  --write-buckets

# Daten schreiben
echo "temperature,location=room1 value=22.5" | \
  docker compose exec -T influxdb influx write \
    --org mintfv \
    --bucket sensors \
    --token <token>

# Query ausführen
docker compose exec influxdb influx query \
  'from(bucket:"sensors") |> range(start:-1h) |> limit(n:10)'
```

## Monitoring

### Health Check

```bash
# Via nginx
curl https://mintfv.peddy.net/influxdb/health

# Direct
docker compose exec influxdb curl http://localhost:8086/health
```

### Metrics

InfluxDB exposiert Prometheus Metrics:

```bash
curl https://mintfv.peddy.net/influxdb/metrics
```

### Logs

```bash
# Live Logs
./mintfv.sh logs influxdb -f

# Letzte 100 Zeilen
./mintfv.sh logs influxdb --tail 100
```

## Integration mit anderen Services

### Node-RED → InfluxDB

Node-RED Flow Beispiel (später):
- MQTT Input Node
- Function Node (Data Processing)
- InfluxDB Output Node

### Grafana → InfluxDB

Siehe oben unter "Grafana als Data Source"

### Externe Geräte → InfluxDB

Tasmota, ESP32, etc. können via HTTP API schreiben:

```bash
# Von externem Gerät
curl -XPOST "https://mintfv.peddy.net/influxdb/api/v2/write?org=mintfv&bucket=sensors" \
  --header "Authorization: Token <token>" \
  --data-raw "temperature,device=tasmota-01 value=22.5"
```

## Weiterführende Links

- [InfluxDB Dokumentation](https://docs.influxdata.com/influxdb/v2.7/)
- [Flux Language](https://docs.influxdata.com/flux/v0.x/)
- [API Reference](https://docs.influxdata.com/influxdb/v2.7/api/)
- [Best Practices](https://docs.influxdata.com/influxdb/v2.7/write-data/best-practices/)
