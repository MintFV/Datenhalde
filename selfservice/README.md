# Selfservice-Portal

Self-Service-Webportal für MintFV — Benutzer registrieren sich, verifizieren ihre E-Mail und verwalten eigenständig MQTT-Accounts.

**Container:** mintfv-selfservice (UID 2007:2100)  
**Image:** python:3.12-alpine (eigenes Dockerfile, Build- und Runtime-Stage)  
**Framework:** Flask 3.1 + SQLAlchemy + Flask-Migrate + Flask-Mailman + gunicorn  
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
├── Dockerfile                  # Selfservice-Container (python:3.12-alpine)
├── Dockerfile.mosquitto-reload # Sidecar-Container (alpine)
├── entrypoint.sh               # gunicorn Startup (inkl. DB-Migration)
├── mosquitto-reload.sh         # Sidecar Watch-Script
├── requirements.txt            # Python-Abhängigkeiten
├── data/                       # SQLite-Datenbank (Volume)
│   └── selfservice.db
├── migrations/                 # Alembic/Flask-Migrate
│   ├── alembic.ini             # Alembic-Konfiguration
│   ├── env.py                  # Migration-Environment
│   ├── script.py.mako          # Template für neue Migrationen
│   └── versions/               # Migrations-Dateien
│       └── 001_initial.py      # Initiales Schema
└── app/
    ├── __init__.py             # Flask App Factory
    ├── config.py               # Konfiguration (Env-Variablen)
    ├── models.py               # SQLAlchemy Models (User, Tenant, MqttAccount, Device)
    ├── extensions.py           # Flask-Erweiterungen (db, login_manager)
    ├── static/                 # Statische Dateien
    │   ├── css/style.css       # Custom CSS (MintFV-Theme, responsive)
    │   └── img/                # Logo-Dateien
    │       ├── logo.png        # Logo (Vollgröße, für Auth-Seiten)
    │       └── logo-small.webp # Logo (Thumbnail, für Navbar)
    ├── auth/                   # Authentifizierung
    │   ├── routes.py           # Login, Registrierung, Verifikation, Passwort
    │   ├── forms.py            # WTForms-Formulare
    │   └── email.py           # E-Mail-Versand (Flask-Mailman)
    ├── dashboard/              # Benutzer-Dashboard
    │   └── routes.py
    ├── mqtt/                   # MQTT-Account-Verwaltung
    │   ├── routes.py
    │   └── service.py          # Python-Port von manage_mqtt_users.sh
    └── templates/              # Jinja2-Templates (Bootstrap 5 + Icons, deutsch)
        ├── base.html           # Layout mit Navbar, Logo, Footer
        ├── auth/               # Login, Register, Passwort, Resend
        ├── dashboard/          # Dashboard-Übersicht
        └── mqtt/               # MQTT-Account CRUD
```

---

## ⚙️ Konfiguration

### Umgebungsvariablen

| Variable | Beschreibung | Default |
|----------|-------------|---------|
| `SELFSERVICE_SECRET_KEY` | Geheimer Schlüssel für Sessions/Token | `change-me-in-production` |
| `DOMAIN` | Domain für E-Mail-Links | `localhost` |
| `SMTP_HOST` | SMTP-Relay Hostname (→ `MAIL_SERVER`) | `smtp-relay` |
| `SMTP_PORT` | SMTP-Relay Port (→ `MAIL_PORT`) | `8025` |
| `SMTP_FROM` | Absender-Adresse (→ `MAIL_DEFAULT_SENDER`) | `noreply@{DOMAIN}` |
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
- **Bestätigung erneut senden** (`/selfservice/verifizierung-erneut-senden`) — Falls E-Mail nicht ankam
- **Login** (`/selfservice/anmelden`)
- **Passwort ändern** (`/selfservice/passwort-aendern`) — Für eingeloggte Benutzer (über Navbar-Dropdown)
- **Passwort vergessen** (`/selfservice/passwort-vergessen`) — Reset-Link per E-Mail (gültig 1h)

### Tenant- & Geräteverwaltung
- **Tenant beantragen** (`/selfservice/tenant/beantragen`) — Name, Schultyp, Bundesland, Ort, Kontakt, GPS; Tenant-ID wird nach `03_MQTT_Topic_Struktur.md` erzeugt (`de-{bundesland}-{schultyp}-{name}`)
- **Freigabe** (`/selfservice/admin/tenants`, nur `role=admin`) — Tenants freigeben oder suspendieren; neue Tenants starten mit Status `pending`
- **Übersicht** (`/selfservice/tenant/uebersicht`) — eigener Tenant und Geräte
- **Geräte** — anlegen/bearbeiten/löschen (`/selfservice/tenant/<id>/geraete/neu`, `/selfservice/tenant/geraete/<id>/bearbeiten|loeschen`) inkl. Verknüpfung mit einem MQTT-Account

### MQTT-Account-Verwaltung
- **Übersicht** (`/selfservice/mqtt/`) — Alle eigenen MQTT-Accounts des Tenants inkl. effektivem Topic
- **Account erstellen** (`/selfservice/mqtt/erstellen`) — Username + Passwort, Rolle (`admin` / `sensor` / `nodered`) und optionales Gerät; Zugangsdaten werden **einmalig** angezeigt
- **Passwort ändern** (`/selfservice/mqtt/<id>/passwort`) — ebenfalls einmalige Anzeige der neuen Zugangsdaten
- **Account löschen** (`/selfservice/mqtt/<id>/loeschen`)

> **Hinweis:** MQTT-Accounts setzen einen **freigegebenen** Tenant (`status=active`) voraus. Die Rollen bestimmen die ACL: `admin` → `readwrite umweltbox/{tenant}/#`, `sensor` → `write umweltbox/{tenant}/{gerät}/#` + `read .../cmnd/{gerät}/#`, `nodered` → `read umweltbox/{tenant}/#`. Unbekannte Rollen und Sensoren ohne Gerät werden abgewiesen (fail-closed). Siehe `docs/Projekt-Meta-Doku/10_Doku_Code_Abgleich_2026-11.md`.

### Dashboard / Verbindungsdaten
- **Dashboard** (`/selfservice/dashboard`) — Tenant-Status, Anzahl MQTT-Accounts/Geräte sowie ein Tasmota-artiges Panel mit Host, Port 8883, TLS, Client, User, maskiertem Passwort, Topic und Full Topic inkl. Copy-Button.

### Rate Limiting
- Global: 60/Minute pro IP (Flask-Limiter-Default)
- Registrierung: 109/Stunde
- Login: 109/Minute
- Passwort vergessen: 109/Stunde
- Bestätigung erneut senden: 109/Stunde
- Passwort ändern (Portal): 109/Stunde
- nginx: 5 req/s pro IP (Zone `selfservice_general`, burst 30)

---

## 🎨 Frontend

- **Bootstrap 5.3.3** (CDN) + **Bootstrap Icons 1.11.3** (CDN)
- **Custom CSS** (`app/static/css/style.css`) mit kontrastreichem MintFV-Farbschema (`#1b5e20`) und Dark Mode
- **Logo** in Navbar (WebP-Thumbnail) und Auth-Seiten (PNG)
- **Responsive Design**: Fluid Typography/Spacing, Container Queries, CSS-Grid-Auto-Fit, Touch-Targets (≥ 44 px), Breiten bis 2200 px
- **Navbar-Dropdown** für Benutzerprofil (Passwort ändern, Abmelden); Navigation für Dashboard, MQTT, Tenant und (nur Admin) Freigaben

---

## 🔒 Sicherheit

### Container-Sicherheit
- Nicht-Root: UID 2007:2100 (selfservice), UID 2003:2100 (mosquitto-reload)
- `read_only: true` Dateisystem
- `no-new-privileges`, `cap_drop: ALL`
- Mosquitto-Reload: Nur `CAP_KILL` für SIGHUP

### Passwort-Hashing
- MQTT: Mosquitto PBKDF2-SHA512 (`$7$101$<salt>$<hash>`)
- Benutzer: Werkzeug-Default (`generate_password_hash()` ohne Verfahrensangabe, derzeit scrypt)

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

# Benutzer auflisten
./list_selfservice_users.sh
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

---

## 🔄 Datenbank-Migrationen

Schema-Änderungen werden über **Flask-Migrate** (Alembic) verwaltet.

### Automatischer Ablauf

Beim Containerstart führt `entrypoint.sh` automatisch `flask db upgrade` aus — neue Migrationen werden ohne manuellen Eingriff angewandt.

### Neue Migration erstellen (Entwicklung)

```bash
# Im Container:
docker compose exec selfservice flask --app 'app:create_app()' db migrate -m "Beschreibung"

# Migration prüfen:
docker compose exec selfservice cat migrations/versions/<revision>.py

# Anwenden:
docker compose exec selfservice flask --app 'app:create_app()' db upgrade
```

### Bestehende DB auf Migrationen umstellen

Falls die DB bereits existiert (vor Flask-Migrate), einmalig stampen:

```bash
docker compose exec selfservice flask --app 'app:create_app()' db stamp head
```

### Migration rückgängig machen

```bash
docker compose exec selfservice flask --app 'app:create_app()' db downgrade -1
```
