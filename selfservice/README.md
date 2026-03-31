# Selfservice-Portal

Self-Service-Webportal für MintFV — Benutzer registrieren sich, verifizieren ihre E-Mail und verwalten eigenständig MQTT-Accounts.

**Container:** mintfv-selfservice (UID 2007:2100)  
**Image:** python:3.12-slim (eigenes Dockerfile)  
**Framework:** Flask 3.1 + SQLAlchemy + gunicorn  
**URL:** https://mintfv.peddy.net/selfservice/

---

## 🏗️ Architektur

```
Browser → nginx:443 /selfservice/ → selfservice:5000 (Flask/gunicorn)
                                        ├─ SQLite (Benutzer, Tenants, MQTT-Accounts)
                                        ├─ mosquitto/config/ (passwd + ACL Dateien)
                                        └─ selfservice-reload Volume → mosquitto-reload Sidecar
                                                                          └─ SIGHUP → mosquitto
```

### Mosquitto-Reload Sidecar

Separater Container (`mosquitto-reload`, UID 2003:2100), der per Shared PID-Namespace (`pid: "service:mosquitto"`) ein SIGHUP an den Mosquitto-Broker sendet, wenn das Selfservice-Portal MQTT-Konfigurationen ändert.

**Ablauf:**
1. Selfservice schreibt Trigger-Datei in das `selfservice-reload` Volume
2. Sidecar erkennt die Datei via `inotifywait` (Fallback: Polling alle 5s)
3. Sidecar sendet `SIGHUP` an Mosquitto (Reload Passwort/ACL-Dateien)
4. Sidecar löscht die Trigger-Datei

---

## 📁 Verzeichnisstruktur

```
selfservice/
├── Dockerfile                  # Selfservice-Container (python:3.12-slim)
├── Dockerfile.mosquitto-reload # Sidecar-Container (alpine)
├── entrypoint.sh               # gunicorn Startup
├── mosquitto-reload.sh         # Sidecar Watch-Script
├── requirements.txt            # Python-Abhängigkeiten
├── data/                       # SQLite-Datenbank (Volume)
│   └── selfservice.db
└── app/
    ├── __init__.py             # Flask App Factory
    ├── config.py               # Konfiguration (Env-Variablen)
    ├── models.py               # SQLAlchemy Models (User, Tenant, MqttAccount, Device)
    ├── extensions.py           # Flask-Erweiterungen (db, login_manager)
    ├── auth/                   # Authentifizierung (Registrierung, Login, E-Mail-Verifikation)
    │   └── routes.py
    ├── dashboard/              # Benutzer-Dashboard
    │   └── routes.py
    ├── mqtt/                   # MQTT-Account-Verwaltung
    │   ├── routes.py
    │   └── service.py          # Python-Port von manage_mqtt_users.sh
    └── templates/              # Jinja2-Templates (Bootstrap 5, deutsch)
        ├── base.html
        ├── auth/
        ├── dashboard/
        └── mqtt/
```

---

## ⚙️ Konfiguration

### Umgebungsvariablen

| Variable | Beschreibung | Default |
|----------|-------------|---------|
| `SELFSERVICE_SECRET_KEY` | Geheimer Schlüssel für Sessions/Token | `change-me-in-production` |
| `DOMAIN` | Domain für E-Mail-Links | `mintfv.example.com` |
| `SMTP_HOST` | SMTP-Relay Hostname | `smtp-relay` |
| `SMTP_PORT` | SMTP-Relay Port | `8025` |
| `SMTP_FROM` | Absender-Adresse | `noreply@{DOMAIN}` |
| `MOSQUITTO_PASSWD_FILE` | Pfad zur Passwort-Datei | `/mosquitto/config/mosquitto.passwd` |
| `MOSQUITTO_ACL_FILE` | Pfad zur ACL-Datei | `/mosquitto/config/mosquitto.acl` |
| `MOSQUITTO_RELOAD_DIR` | Verzeichnis für Reload-Trigger | `/app/reload` |

### Secret Key generieren

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Den generierten Wert in `.env` als `SELFSERVICE_SECRET_KEY` setzen.

---

## 🔑 Funktionen

### Benutzer-Authentifizierung
- **Registrierung** (`/selfservice/registrieren`) — E-Mail + Passwort
- **E-Mail-Verifikation** — Token per E-Mail (gültig 24h)
- **Login** (`/selfservice/anmelden`)
- **Passwort vergessen** (`/selfservice/passwort-vergessen`) — Reset-Link per E-Mail (gültig 1h)

### MQTT-Account-Verwaltung
- **Übersicht** (`/selfservice/mqtt/`) — Alle eigenen MQTT-Accounts
- **Account erstellen** (`/selfservice/mqtt/erstellen`) — Username + Passwort, ACL-Regeln
- **Passwort ändern** (`/selfservice/mqtt/<id>/passwort-aendern`)
- **Account löschen** (`/selfservice/mqtt/<id>/loeschen`)

### Rate Limiting
- Registrierung: 3/Stunde
- Login: 5/Minute
- Passwort-Reset: 3/Stunde
- nginx: 5 req/s pro IP (Zone `selfservice_general`)

---

## 🔒 Sicherheit

### Container-Sicherheit
- Nicht-Root: UID 2007:2100 (selfservice), UID 2003:2100 (mosquitto-reload)
- `read_only: true` Dateisystem
- `no-new-privileges`, `cap_drop: ALL`
- Mosquitto-Reload: Nur `CAP_KILL` für SIGHUP

### Passwort-Hashing
- MQTT: Mosquitto PBKDF2-SHA512 (`$7$101$<salt>$<hash>`)
- Benutzer: Werkzeug (pbkdf2:sha256)

### Datei-Locking
- `fcntl.flock()` für gleichzeitige Zugriffe auf `mosquitto.passwd` und `mosquitto.acl`

---

## 🚀 Quick Start

```bash
# Container bauen und starten
docker compose build selfservice mosquitto-reload
docker compose up -d selfservice mosquitto-reload

# Status prüfen
docker compose ps selfservice mosquitto-reload

# Logs
docker compose logs -f selfservice
docker compose logs -f mosquitto-reload

# Health-Check
curl -fsS https://mintfv.peddy.net/selfservice/health
```

---

## ⚠️ Troubleshooting

### Problem: 502 Bad Gateway
```bash
# Container läuft?
docker compose ps selfservice

# Logs prüfen
docker compose logs selfservice | tail -20
```

### Problem: E-Mails kommen nicht an
```bash
# SMTP-Relay erreichbar?
docker compose exec selfservice sh -c "nc -zv smtp-relay 8025"

# SMTP-Relay Logs
docker compose logs smtp-relay
```

### Problem: MQTT-Änderungen werden nicht übernommen
```bash
# Mosquitto-Reload Sidecar prüfen
docker compose logs mosquitto-reload

# Trigger manuell auslösen
docker compose exec selfservice sh -c 'echo "test" > /app/reload/reload.trigger'

# Prüfen ob Trigger erkannt wurde
docker compose logs mosquitto-reload --tail=5
```

### Problem: Datenbank-Fehler
```bash
# Berechtigungen prüfen
docker compose exec selfservice ls -la /app/data/

# Datenbank muss UID 2007:2100 gehören
docker compose exec -u root selfservice chown 2007:2100 /app/data/selfservice.db
```
