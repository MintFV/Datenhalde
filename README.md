# MintFV – IoT-Plattform

Self-hosted IoT-Plattform auf Basis von Docker Compose. Bietet MQTT-Messaging, Zeitreihen-Datenbank, Flow-basierte Automatisierung, Visualisierung und ein Self-Service-Portal für die Benutzerverwaltung.

## Services

| Service | Beschreibung | Interner Port |
|---------|-------------|---------------|
| **nginx** | Reverse Proxy, TLS-Terminierung, Rate Limiting | 8080 / 8443 |
| **certbot** | Automatische Let's Encrypt Zertifikatserneuerung | – |
| **mosquitto** | MQTT Broker (inkl. WebSocket) | 1883 / 9001 |
| **Node-RED** | Flow-basierte IoT-Automatisierung | 1880 |
| **InfluxDB 3 Core** | Zeitreihen-Datenbank | 8181 |
| **Grafana** | Dashboards & Monitoring | 3000 |
| **Selfservice-Portal** | Benutzer-Registrierung & MQTT-Account-Verwaltung | 5000 |
| **SMTP Relay** | Ausgehender Mailversand (Exim → Smarthost) | 8025 |

Hilfs-Services (nur intern, kein externer Zugriff):

| Service | Beschreibung | Interner Port |
|---------|-------------|---------------|
| **certbot-init** | One-Shot Init-Container (Dummy-Zertifikat + Verzeichnisse) | – |
| **mosquitto-admin** | Management-Container für `mosquitto_passwd`-Operationen | – |
| **mosquitto-reload** | Sidecar: SIGHUP an Mosquitto bei ACL/Passwort-Änderungen | – |
| **mcp-grafana** | Grafana MCP-Server (Model Context Protocol) | – |
| **decap-cms** | Decap CMS (Git-basiertes Content-Management, GitHub-OAuth) | 80 |

## Architektur

```
Internet
  │
  ├── :80  ──► nginx (HTTP → HTTPS Redirect)
  ├── :443 ──► nginx (TLS) ──┬── /grafana/      → Grafana
  │                           ├── /nodered/      → Node-RED
  │                           ├── /selfservice/  → Flask-Portal
  │                           └── /influxdb/     → InfluxDB API
  └── :8883 ─► nginx (MQTTS Stream) ──► Mosquitto
```

## Schnellstart

```bash
# 1. Repository klonen
git clone https://github.com/MintFV/Datenhalde.git && cd Datenhalde

# 2. Konfiguration anlegen
cp env.example .env
# .env editieren: DOMAIN, EMAIL, Passwörter setzen

# 3. SMTP-Passwort separat anlegen
echo "SMTP_PASSWORD='dein-smtp-passwort'" > .env.smtp.password

# 4. Stack starten
docker compose up -d
```

Die Datei `.env.smtp.password` wird in `docker-compose.yaml` über `env_file:` in den Container `smtp-relay` geladen. Sie muss nach der Installation folgende Zeile enthalten:

```
SMTP_PASSWORD='XXXXXXXXXXXXXXXXXXXXXXX'
```

Der Wert ist das Passwort für den externen Smarthost (zugehöriger User: `SMTP_USER_PROVIDER` in `.env`). Die Datei wird nicht committet.

Beim ersten Start erstellt `certbot-init` ein selbstsigniertes Zertifikat. Sobald nginx läuft, holt Certbot automatisch ein echtes Let's Encrypt Zertifikat.

## Voraussetzungen

- Docker Engine ≥ 24 mit Compose V2
- Öffentliche Domain mit DNS A-Record auf den Server
- Ports 80, 443, 8883 offen

## Sicherheitskonzept

- Alle Container laufen als **nicht-root** (dedizierte UIDs ab 2001; Ausnahme: smtp-relay nutzt den Image-eigenen `exim`-User 100:101)
- Gemeinsame GID 2100 für Shared-Volume-Zugriff (z. B. TLS-Zertifikate)
- `read_only: true` + `tmpfs` für beschreibbare Verzeichnisse
- `no-new-privileges`, `cap_drop: ALL` + minimale `cap_add`
- Ressource-Limits (CPU, Memory, PIDs) pro Container
- nginx: Rate Limiting, Security Headers, IP-Blocking

## Verzeichnisstruktur

```
├── certbot/          # Let's Encrypt Zertifikate & Logs
├── grafana/          # Dashboards, Provisioning, Daten
├── influxdb/         # InfluxDB 3 Daten & Token
├── mosquitto/        # MQTT Broker Config, Passwörter, ACLs
├── nginx/            # Reverse Proxy Konfiguration
├── nodered/          # Node-RED Flows & Packages
├── selfservice/      # Flask-Portal (Dockerfile, App, Migrations)
├── smtp-relay/       # Exim Spool (wird beim ersten Start erstellt)
├── tests/            # Playwright Smoke Tests
└── docker-compose.yaml
```

## Weiterführende Dokumentation

- [certbot/SSL-SETUP.md](certbot/SSL-SETUP.md) – SSL/HTTPS Einrichtung
- [nginx/README.md](nginx/README.md) – Reverse Proxy & Rate Limiting
- [mosquitto/README.md](mosquitto/README.md) – MQTT Broker & ACL
- [grafana/README.md](grafana/README.md) – Grafana Dashboards
- [influxdb/README.md](influxdb/README.md) – InfluxDB 3 Core
- [nodered/README.md](nodered/README.md) – Node-RED Flows
- [selfservice/README.md](selfservice/README.md) – Selfservice-Portal
- [BACKUP.md](BACKUP.md) – Backup-Strategie

## Lizenz

Privates Repository – kein öffentlicher Zugang.
