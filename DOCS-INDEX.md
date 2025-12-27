# MintFV Dokumentations-Index

Willkommen bei der MintFV-Dokumentation! Diese Übersicht hilft dir, schnell die richtige Dokumentation zu finden.

---

## 🚀 Getting Started

| Dokument | Beschreibung | Wann nutzen? |
|----------|--------------|--------------|
| [README.md](README.md) | **Start hier!** Projekt-Übersicht, Quick Start, Architektur | Erstes Setup, Überblick |
| [SSL-SETUP.md](SSL-SETUP.md) | HTTPS/SSL mit Let's Encrypt einrichten | SSL-Zertifikate erstellen/erneuern |
| [DOCKER.md](DOCKER.md) | Docker Conventions, UID/GID Security | Neue Services hinzufügen, Security-Fragen |

---

## 🔧 Service-Dokumentation

### Datenbanken & Storage

| Service | Dokumentation | Beschreibung |
|---------|---------------|--------------|
| **InfluxDB** | [INFLUXDB.md](INFLUXDB.md) | Time-Series Datenbank - Setup, APIs, Token Management |

### Visualisierung & Monitoring

| Service | Dokumentation | Beschreibung |
|---------|---------------|--------------|
| **Grafana** | [GRAFANA.md](GRAFANA.md) | Dashboard & Visualisierung - Setup, Data Sources |

### Automation & Processing

| Service | Dokumentation | Beschreibung |
|---------|---------------|--------------|
| **Node-RED** | [NODERED.md](NODERED.md) | Flow-basierte Programmierung - Setup, Security, InfluxDB Integration |

### Messaging (geplant)

| Service | Status | Beschreibung |
|---------|--------|--------------|
| **Mosquitto** | ⏳ Geplant | MQTT Broker für IoT-Kommunikation |

---

## 🔐 Operations & Security

| Dokument | Beschreibung | Wann nutzen? |
|----------|--------------|--------------|
| [BACKUP.md](BACKUP.md) | Backup-Strategie, rsync-Skripte, Retention, Restore | Backups einrichten, Daten wiederherstellen |
| [DOCKER.md](DOCKER.md) | Security Best Practices, UID/GID Strategie | Security-Audit, Permissions-Probleme |

---

## ⚙️ Konfiguration

| Datei | Beschreibung | Dokumentation |
|-------|--------------|---------------|
| [config-example.yaml](config-example.yaml) | Haupt-Konfiguration (Domain, Services, Limits) | [README.md](README.md#konfiguration) |
| [docker-compose.yaml](docker-compose.yaml) | Service-Definitionen, Networking | [DOCKER.md](DOCKER.md) |
| `.env.example` | Environment-Variablen Template | Service-spezifische Docs |
| [nginx/conf/](nginx/conf/) | Nginx Konfiguration (SSL, Reverse Proxy, Rate Limits) | [SSL-SETUP.md](SSL-SETUP.md) |

---

## 📚 Quick Reference Guides

### Häufige Aufgaben

#### SSL/HTTPS Management
```bash
# Status prüfen
docker compose exec certbot certbot certificates

# Manuell erneuern
docker compose exec certbot certbot renew --force-renewal
```
📖 Details: [SSL-SETUP.md](SSL-SETUP.md)

#### Services verwalten
```bash
# Alle Services starten
./mintfv.sh start

# Status prüfen
docker compose ps

# Logs ansehen
docker compose logs -f [service]
```
📖 Details: [README.md](README.md#verwendung)

#### Backup erstellen
```bash
# Vollständiges Backup
sudo rsync -avz --delete \
  ./influxdb/data/ \
  /backup/mintfv/influxdb/
```
📖 Details: [BACKUP.md](BACKUP.md)

#### InfluxDB Daten abfragen
```bash
# Token holen
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')

# Query ausführen
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 query --database mintfv "SELECT * FROM measurement LIMIT 10"
```
📖 Details: [INFLUXDB.md](INFLUXDB.md#quick-reference)

#### Node-RED absichern
```bash
# Passwort-Hash generieren
docker compose exec nodered node-red admin hash-pw

# settings.js editieren
nano ./nodered/data/settings.js
```
📖 Details: [NODERED.md](NODERED.md#quick-start-guide)

---

## 🔍 Troubleshooting

### Nach Problem-Kategorie

| Problem | Siehe |
|---------|-------|
| SSL-Zertifikat ungültig/abgelaufen | [SSL-SETUP.md → Troubleshooting](SSL-SETUP.md#troubleshooting) |
| Container startet nicht | [DOCKER.md → Healthchecks](DOCKER.md#healthchecks), Service-spezifische Docs |
| Permission Denied Fehler | [DOCKER.md → UID/GID Strategy](DOCKER.md#uid-gid-strategie) |
| InfluxDB Connection Failed | [INFLUXDB.md → Troubleshooting](INFLUXDB.md#troubleshooting) |
| Grafana Login funktioniert nicht | [GRAFANA.md → Troubleshooting](GRAFANA.md#troubleshooting) |
| Node-RED Login/WebSocket Fehler | [NODERED.md → Troubleshooting](NODERED.md#troubleshooting) |
| Backup/Restore Probleme | [BACKUP.md → Restore](BACKUP.md#restore-procedures) |

### Nach Service

| Service | Troubleshooting-Sektion |
|---------|-------------------------|
| **nginx** | [SSL-SETUP.md](SSL-SETUP.md#troubleshooting) |
| **certbot** | [SSL-SETUP.md](SSL-SETUP.md#troubleshooting) |
| **InfluxDB** | [INFLUXDB.md](INFLUXDB.md#troubleshooting) + Quick Reference |
| **Grafana** | [GRAFANA.md](GRAFANA.md#troubleshooting) |
| **Node-RED** | [NODERED.md](NODERED.md#troubleshooting) |

---

## 📖 Weitere Ressourcen

### Externe Dokumentation

- **Docker Compose**: https://docs.docker.com/compose/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **InfluxDB 3 Core**: https://docs.influxdata.com/influxdb3/
- **Grafana**: https://grafana.com/docs/
- **Node-RED**: https://nodered.org/docs/

### Community & Support

- **GitHub Issues**: Für Bug-Reports und Feature-Requests
- **Docker Hub**: Für Image-Updates und Changelogs

---

## 📝 Dokumentations-Standards

Alle Service-Dokumentationen folgen dieser Struktur:

1. **Quick Reference** - Häufigste Kommandos für schnellen Zugriff
2. **Übersicht** - Was macht der Service, warum nutzen wir ihn
3. **Quick Start** - Minimale Schritte zum Laufen bringen
4. **Konfiguration** - Detaillierte Einstellungen
5. **Security** - Authentifizierung, Permissions
6. **Integration** - Zusammenspiel mit anderen Services
7. **Troubleshooting** - Häufige Probleme und Lösungen
8. **Backup & Restore** - Datensicherung (wenn relevant)
9. **Advanced Topics** - Erweiterte Konfigurationen

---

## 🔄 Dokumentation aktualisieren

Beim Hinzufügen neuer Services oder Features:

1. ✅ Service-Dokumentation nach Standard-Struktur erstellen
2. ✅ Quick Reference-Sektion hinzufügen
3. ✅ Diesen Index (DOCS-INDEX.md) aktualisieren
4. ✅ [README.md](README.md) Service-Liste aktualisieren
5. ✅ [BACKUP.md](BACKUP.md) um neue Backup-Pfade erweitern
6. ✅ [DOCKER.md](DOCKER.md) UID/GID Tabelle aktualisieren (falls neuer Service)

---

**Letzte Aktualisierung**: 27. Dezember 2025
**Version**: MintFV 1.0
