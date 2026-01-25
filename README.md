# ![MintFV Logo](nginx/html/images/logo-cleaned-60x46.webp) MintFV Datenhalde


IoT-Datenplattform mit MQTT, Node-RED, InfluxDB & Grafana.

[![Docker](https://img.shields.io/badge/Docker-required-blue.svg)](https://www.docker.com/)
[![HTTPS](https://img.shields.io/badge/HTTPS-Let's%20Encrypt-green.svg)](https://letsencrypt.org/)

---

## 🚀 Quick Start (5 Minuten)

### Voraussetzungen
- Linux Server mit Docker & Docker Compose
- Domain mit DNS konfiguriert (A-Record auf Server-IP)
- Ports 80/443 offen

### Setup
```bash
git clone https://github.com/your-org/mintfv.git && cd mintfv
cp env.example .env
vi .env  # DOMAIN + EMAIL anpassen
docker compose up -d
```

**Fertig!** Services sind erreichbar unter:
- **Grafana:** https://[DOMAIN]/grafana/ (admin / admin)
- **Node-RED:** https://[DOMAIN]/nodered/
- **InfluxDB:** https://[DOMAIN]/influxdb/ (API only)
- **MQTT:** mqtt://[DOMAIN]:1883 oder wss://[DOMAIN]/mqtt

---

## 📚 Services

| Service | URL / Port | Dokumentation |
|---------|------------|---------------|
| **Grafana** | /grafana/ | [grafana/README.md](grafana/README.md) |
| **Node-RED** | /nodered/ | [nodered/README.md](nodered/README.md) |
| **InfluxDB 3** | /influxdb/ (API) | [influxdb/README.md](influxdb/README.md) |
| **MQTT Broker** | :1883, wss://.../mqtt | [mosquitto/README.md](mosquitto/README.md) |
| **nginx** | :80, :443, :8883 | [nginx/README.md](nginx/README.md) |

---

## 🔐 Demo-Zugangsdaten

⚠️ **Für Tests only - in Produktion ändern!**

### Grafana
- **URL:** https://[DOMAIN]/grafana/
- **Login:** admin / admin (bitte nach Login ändern!)
- **Features:** Dashboards, Alerting, Data Source Management
- **Details:** [grafana/README.md](grafana/README.md)

### MQTT (Mosquitto)
- **Master Admin:** `master-admin` / `master2024!` (Vollzugriff)
- **Monitoring:** `monitoring` / `monitor2024!` (Read $SYS)
- **Tenant A Sensor:** `tenant-a-sensor01` / `sensor01`
- **Tenant A Admin:** `tenant-a-admin` / `alpha2024!`

Vollständige Credentials: [mosquitto/README.md](mosquitto/README.md)

### InfluxDB
- **Token:** Automatisch generiert in `./influxdb/tokens/admin.token`
- **Auslesen:** `cat ./influxdb/tokens/admin.token | jq -r '.token'`

### Node-RED
- **Setup:** Siehe [nodered/README.md](nodered/README.md) für Passwort-Hash Generierung

---

## 🔗 Integration-Beispiele

### ESP32/Arduino → MQTT
```cpp
#include <WiFi.h>
#include <PubSubClient.h>

const char* mqtt_server = "mintfv.peddy.net";
const int mqtt_port = 1883;
const char* mqtt_user = "tenant-a-sensor01";
const char* mqtt_password = "sensor01";

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  client.setServer(mqtt_server, mqtt_port);
  client.connect("ESP32-Sensor01", mqtt_user, mqtt_password);
  client.publish("tenant/tenant-a/sensor01/temperature", "23.5");
}
```

### Node-RED → InfluxDB
1. MQTT In: `tenant/tenant-a/sensor01/+`
2. Function: Parse & Transform
3. InfluxDB Out: `http://influxdb:8181`

---

## ⚡ Wichtige Befehle

```bash
# Services starten
./mintfv.sh start
# oder
docker compose up -d

# Services stoppen
./mintfv.sh stop
# oder
docker compose down

# Status prüfen
docker compose ps

# Logs anzeigen
docker compose logs -f [service]
# Beispiel: docker compose logs -f grafana

# Services neu starten
./mintfv.sh restart
# oder
docker compose restart

# Validierung nach Setup
./validate.sh
```

---

## 🧪 Nach Setup validieren

```bash
# Automatisierte Tests
./validate.sh

# Manuelle Tests
curl -fsS https://[DOMAIN]
curl -u admin:admin https://[DOMAIN]/grafana/api/health
mosquitto_sub -h [DOMAIN] -p 1883 -u monitoring -P monitor2024! -t '$SYS/#' -C 1
```

---

## 🔒 Sicherheit

### Let's Encrypt SSL
- **Automatische Erneuerung** alle 12h
- **HTTPS-Only** (HTTP → HTTPS Redirect)

### Non-Root Container
Alle Services laufen mit dedizierten UIDs:
```
nginx:      2001:2100
certbot:    2002:2100
mosquitto:  2003:2100
nodered:    2004:2100
influxdb:   2005:2100
grafana:    2006:2100
```

**Shared GID 2100** (`ssl-certs`): Ermöglicht sicheren Dateizugriff zwischen Services

- nginx (2001) liest SSL-Zertifikate von certbot (2002)
- Keine 777-Permissions nötig
- Datei-Permissions: 750 (Dirs), 640 (Files)

### Docker Security Best Practices

**❌ NEVER:**

- `chmod 777` oder `chown` mit world-writable permissions
- Container als root laufen lassen
- `--privileged` Flag verwenden

**✅ DO:**

- `docker compose exec` für Commands in Containern
- Explizite user:group (z.B. `2001:2100`)
- Read-only root filesystem + tmpfs für writable dirs
- Capability dropping (`cap_drop: ALL`)
- Resource limits (CPU, Memory, PIDs)
- Health checks für alle Services
- Automatic log rotation (10M max, 3 files)

Siehe Service-README-Dateien für detaillierte Konfiguration.

### Rate Limiting
- InfluxDB: 30 req/s
- Grafana: 100 req/s
- Node-RED: 200 req/s

Details: [nginx/README.md](nginx/README.md)

---

## 📖 Dokumentation

### Setup & Administration

- [certbot/SSL-SETUP.md](certbot/SSL-SETUP.md) - Let's Encrypt Details
- [BACKUP.md](BACKUP.md) - Backup-Strategie

### Services

- [mosquitto/README.md](mosquitto/README.md) - MQTT Broker & Multi-Tenant ACLs
- [nodered/README.md](nodered/README.md) - Flows & Integration
- [influxdb/README.md](influxdb/README.md) - Datenbank & Queries
- [grafana/README.md](grafana/README.md) - Dashboards & Datasources
- [nginx/README.md](nginx/README.md) - Reverse Proxy & MQTT TLS

---

## 🔧 Konfiguration

### .env Datei
Kopiere `env.example` zu `.env` und passe an:
```bash
DOMAIN=mintfv.peddy.net
EMAIL=admin@example.com
RENEWAL_INTERVAL=12h
TZ=Europe/Berlin
```

### Service-spezifische Konfiguration
- **Mosquitto:** `mosquitto/config/mosquitto.conf`
- **Node-RED:** `nodered/data/settings.js`
- **nginx:** `nginx/conf.d/*.conf`

---

## 🐛 Troubleshooting

### Services starten nicht
```bash
# Container-Status prüfen
docker compose ps

# Logs aller Services
docker compose logs

# Spezifischer Service
docker compose logs grafana
```

### HTTPS funktioniert nicht
```bash
# Zertifikat-Status
docker compose exec certbot certbot certificates

# nginx Config testen
docker compose exec nginx nginx -t

# SSL-Setup Dokumentation
cat certbot/SSL-SETUP.md
```

### MQTT Probleme
```bash
# Mosquitto Logs
docker compose logs mosquitto

# ACL Debugging
docker compose logs mosquitto | grep Denied

# Test-Suite
./tmp/test-acl.sh
```

### Service erreichbar aber funktioniert nicht
```bash
# Health Checks prüfen
docker compose ps  # "healthy" Status?

# Einzelner Health Check
docker compose exec grafana curl -fsS http://localhost:3000/api/health
```

---

## 💾 Backup

Wichtige Verzeichnisse für Backup:
```
./certbot/conf/          # SSL-Zertifikate
./influxdb/data/         # Time-Series Datenbank
./grafana/data/          # Dashboards & Konfiguration
./nodered/data/          # Flows
./mosquitto/config/      # MQTT Credentials & ACLs
```

Siehe [BACKUP.md](BACKUP.md) für Details.

---

## 📊 Monitoring

### Container-Status
```bash
docker compose ps
```

### Resource Usage
```bash
docker stats --no-stream
```

### Logs
```bash
# Alle Services
docker compose logs --tail=50

# Live-Logs
docker compose logs -f nginx

# Fehler suchen
docker compose logs | grep -i error
```

---

## 🤝 Support & Contribution

- **Issues:** GitHub Issues
- **Dokumentation:** Siehe `*/README.md` in Service-Verzeichnissen
- **Umweltbox Projekt:** https://github.com/MintFV/Umweltbox

---

## 📜 License

[License Type] - Siehe LICENSE Datei

---

## Merker

- ```sh docker compose exec influxdb curl -s http://localhost:8181/health | jq```
- ```docker compose exec influxdb curl -s http://localhost:8181/ping  |jq```
- ```nc -zv mosquitto 1883```
