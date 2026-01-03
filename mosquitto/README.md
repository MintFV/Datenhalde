# Mosquitto MQTT Broker

**Version:** Eclipse Mosquitto 2.x (Latest)  
**Container:** mintfv-mosquitto (UID 2003:2100)  
**Ports:** 1883 (MQTT), 9001 (WebSocket), 8883 (MQTT TLS via nginx)

---

## 🏗️ Architektur

### Multi-Tenant Setup
```
Client → nginx:8883 (TLS) → mosquitto:1883 (plain)
        └─ ACL-basierte Tenant-Isolation
        └─ Passwort-Authentifizierung
```

**Tenant-Namespaces:**
- `tenant/tenant-a/#` - Firma Alpha GmbH
- `tenant/tenant-b/#` - Stadt Beta
- `tenant/tenant-c/#` - Umwelt Gamma e.V.

### Konfiguration
```
mosquitto/
├── config/
│   ├── mosquitto.conf      # Haupt-Konfiguration
│   ├── mosquitto.passwd    # Passwort-Hashes (git-ignored)
│   └── mosquitto.acl       # ACL-Regeln (git-ignored)
├── data/                   # Persistence (git-ignored)
└── logs/                   # Logs (git-ignored)
```

---

## 🔑 Authentifizierung

**ACL-System:** Pattern-based Access Control
- Admin: Vollzugriff auf alle Topics
- Tenant: Namespace-isoliert (Read/Write nur eigener Namespace)
- Sensoren: Write-Zugriff auf gesamten Tenant-Namespace + Command-Read
- Monitoring: Read-Only $SYS topics

**Demo-Credentials:** Siehe [mosquitto/README.md](mosquitto/README.md#-multi-tenant-credentials-demo)

### Passwörter verwalten

```bash
# Neuen User anlegen oder Passwort ändern (interaktiv)
docker compose exec mosquitto mosquitto_passwd /mosquitto/config/mosquitto.passwd username

# Passwort direkt setzen (nicht-interaktiv)
docker compose exec mosquitto mosquitto_passwd -b /mosquitto/config/mosquitto.passwd username password

# User löschen
docker compose exec mosquitto mosquitto_passwd -D /mosquitto/config/mosquitto.passwd username

# Container neu laden (Passwörter anwenden)
docker compose restart mosquitto
```

**Beispiel:**

```bash
# master-admin Passwort ändern
docker compose exec mosquitto mosquitto_passwd /mosquitto/config/mosquitto.passwd master-admin
# Passwort eingeben: master2024!
```

---

## 🚀 Quick Start

```bash
# Status prüfen
docker compose ps mosquitto
docker compose logs -f mosquitto

# Test-Publikation (Sensor kann auf beliebige Topics im Tenant schreiben)
mosquitto_pub -h mintfv.peddy.net -p 1883 \
  -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-a/raspi4/temperature" -m "22.5"

# ACL-Tests
./tmp/test-acl.sh
```

---

## 📚 Weitere Informationen

- **Setup & Credentials:** [mosquitto/README.md](mosquitto/README.md)
- **ACL Troubleshooting:** [mosquitto/README.md#-troubleshooting](mosquitto/README.md#-troubleshooting)
- **Integration:** [mosquitto/README.md#-integration](mosquitto/README.md#-integration)
- **Test-Suite:** [tmp/test-acl.sh](tmp/test-acl.sh)
- **Upstream Docs:** [Eclipse Mosquitto](https://mosquitto.org/documentation/)
