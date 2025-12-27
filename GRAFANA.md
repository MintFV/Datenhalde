# Grafana Setup und Konfiguration

## Überblick

Grafana ist eine Open-Source Visualisierungs- und Monitoring-Platform für Time-Series Daten. In diesem Setup läuft Grafana hinter nginx mit SSL und ist über `/grafana/` erreichbar.

**Quick Links:**
- 📖 [InfluxDB Integration](INFLUXDB.md) - Datenquelle einrichten
- 📖 [Backup-Strategie](BACKUP.md) - Dashboards sichern
- 📖 [Node-RED Integration](NODERED.md) - Daten von Node-RED visualisieren

---

## Zugriff

Grafana ist über nginx Reverse Proxy erreichbar:

- **URL**: `https://mintfv.peddy.net/grafana/`
- **Standard-Login**: `admin` / `admin`
- **⚠️ WICHTIG**: Bitte beim ersten Login das Passwort ändern!

## Technische Details

### Container-Konfiguration

- **Image**: `grafana/grafana:latest`
- **User ID**: 2006:2100
- **Shared GID**: 2100 (ssl-certs)
- **Interner Port**: 3000
- **Externer Zugriff**: Nur via nginx reverse proxy

### Verzeichnisstruktur

```
grafana/
└── data/                   # Persistente Daten [BACKUP]
    ├── grafana.db         # SQLite Datenbank
    ├── plugins/           # Installierte Plugins
    └── ...
```

### Umgebungsvariablen

```yaml
GF_SERVER_ROOT_URL: https://mintfv.peddy.net/grafana/
GF_SERVER_SERVE_FROM_SUB_PATH: true
GF_SECURITY_ADMIN_USER: admin
GF_SECURITY_ADMIN_PASSWORD: admin  # ⚠️ Ändern!
GF_AUTH_ANONYMOUS_ENABLED: false
GF_LOG_MODE: console
GF_LOG_LEVEL: info
GF_ANALYTICS_REPORTING_ENABLED: false
GF_ANALYTICS_CHECK_FOR_UPDATES: false
GF_DATABASE_TYPE: sqlite3
GF_DATABASE_PATH: /var/lib/grafana/grafana.db
```

## Erste Schritte

### 1. Login

1. Öffne `https://mintfv.peddy.net/grafana/`
2. Login mit `admin` / `admin`
3. Ändere das Passwort!

### 2. InfluxDB Data Source einrichten (später)

Wenn InfluxDB läuft:

1. **Configuration** → **Data Sources** → **Add data source**
2. Wähle **InfluxDB**
3. Konfiguration:
   - Name: `InfluxDB`
   - URL: `http://influxdb:8086`
   - Database: `mintfv`
   - User: [siehe InfluxDB-Config]
   - Password: [siehe InfluxDB-Config]
4. **Save & Test**

### 3. Dashboard erstellen

1. **Dashboards** → **New Dashboard**
2. **Add visualization**
3. Wähle Data Source
4. Query konfigurieren
5. Speichern

## Security

### Passwort ändern

**Via Web UI:**
1. User-Icon (unten links) → **Profile**
2. **Change Password**

**Via Environment Variable (empfohlen für Production):**
1. Bearbeite `docker-compose.yaml`:
   ```yaml
   environment:
     - GF_SECURITY_ADMIN_PASSWORD=<dein-sicheres-passwort>
   ```
2. Restart: `./mintfv.sh restart`

**⚠️ WICHTIG**: Passwort nie in Git committen!

### Zusätzliche Security Features

Grafana läuft mit Security Hardening:
- Read-only Filesystem
- Dropped Capabilities (nur CHOWN, SETGID, SETUID)
- No New Privileges
- Resource Limits (256M RAM, 0.5 CPU)
- Alle Logs nach STDOUT/STDERR

## nginx Reverse Proxy

Konfiguration in `nginx/conf/ssl.conf`:

```nginx
location /grafana/ {
    proxy_pass http://grafana:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # WebSocket support für live updates
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Buffering aus
    proxy_buffering off;
    proxy_request_buffering off;
}
```

## Troubleshooting

### Grafana startet nicht

```bash
# Logs prüfen
./mintfv.sh logs grafana

# Status prüfen
docker compose ps grafana

# Container neu starten
docker compose restart grafana
```

### Login funktioniert nicht

```bash
# Passwort in docker-compose.yaml prüfen
grep GF_SECURITY_ADMIN_PASSWORD docker-compose.yaml

# Container neu erstellen (setzt Passwort zurück)
docker compose down grafana
docker compose up -d grafana
```

### Reverse Proxy funktioniert nicht

```bash
# nginx-Config prüfen
docker compose exec nginx nginx -T | grep grafana

# nginx neu laden
docker compose exec nginx nginx -s reload

# Direct access testen (sollte 302 redirect sein)
docker compose exec grafana curl -I http://localhost:3000/grafana/
```

### Permissions-Fehler

```bash
# Ownership prüfen
ls -la ./grafana/data/

# Falls nötig: Korrigieren
sudo chown -R 2006:2100 ./grafana/data/
sudo chmod 750 ./grafana/data/
```

## Plugins installieren

### Via Web UI

1. **Administration** → **Plugins**
2. Plugin suchen
3. **Install**

### Via Container Exec

```bash
# Plugin installieren
docker compose exec -u 2006:2100 grafana grafana-cli plugins install <plugin-name>

# Container neu starten
docker compose restart grafana
```

### Beliebte Plugins

- `grafana-clock-panel` - Clock Panel
- `grafana-piechart-panel` - Pie Chart
- `grafana-worldmap-panel` - World Map

## Backup & Restore

**Wichtig:** Grafana Dashboards und Datenquellen-Konfigurationen sollten regelmäßig gesichert werden!

### Was muss gesichert werden?

```
grafana/data/
├── grafana.db         # SQLite DB (Dashboards, Users, Settings) [KRITISCH]
├── plugins/           # Installierte Plugins
└── sessions/          # User-Sessions (optional)
```

### Backup erstellen

```bash
# Mit mintfv Backup-Script (empfohlen)
./backup.sh create

# Oder manuell mit rsync
sudo rsync -avz --delete \
  ./grafana/data/ \
  /backup/mintfv/grafana/data/
```

### Restore

```bash
# Container stoppen
docker compose stop grafana

# Backup wiederherstellen
sudo rsync -avz --delete \
  /backup/mintfv/grafana/data/ \
  ./grafana/data/

# Permissions korrigieren
sudo chown -R 2006:2100 ./grafana/data
sudo chmod -R 750 ./grafana/data

# Container starten
docker compose start grafana
```

**Detaillierte Backup-Strategie:** Siehe [BACKUP.md](BACKUP.md)

---

## Siehe auch

- **[INFLUXDB.md](INFLUXDB.md)** - InfluxDB als Datenquelle einrichten
- **[NODERED.md](NODERED.md)** - Daten mit Node-RED vorverarbeiten
- **[BACKUP.md](BACKUP.md)** - Vollständige Backup-Strategie
- **[DOCKER.md](DOCKER.md)** - UID/GID Permissions verstehen
- **[README.md](README.md)** - Projekt-Übersicht und Quick Start

---

**Letzte Aktualisierung**: 27. Dezember 2025

## Performance Tuning

### Resource Limits anpassen

In `config.yaml`:

```yaml
services:
  grafana:
    memory_limit: 512M    # Mehr RAM für größere Dashboards
    cpu_limit: 1.0        # Mehr CPU für komplexe Queries
```

Nach Änderung:
```bash
./mintfv.sh restart
```

## Weiterführende Links

- [Grafana Dokumentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Community](https://community.grafana.com/)
- [InfluxDB Data Source Plugin](https://grafana.com/docs/grafana/latest/datasources/influxdb/)
