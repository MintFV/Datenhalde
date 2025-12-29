# Mosquitto MQTT Broker - Architektur-Übersicht

**Version:** Eclipse Mosquitto 2.x (Latest)  
**Container:** mintfv-mosquitto (UID 2003:2100)  
**Ports:** 1883 (MQTT), 9001 (WebSocket), 8883 (MQTT TLS via nginx)

> 📖 **Vollständige Dokumentation:** [mosquitto/README.md](mosquitto/README.md)

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
- Sensoren: Write-Only + Command-Read
- Monitoring: Read-Only $SYS topics

**Demo-Credentials:** Siehe [mosquitto/README.md](mosquitto/README.md#-multi-tenant-credentials-demo)

---

## 🚀 Quick Start

```bash
# Status prüfen
docker compose ps mosquitto
docker compose logs -f mosquitto

# Test-Publikation
mosquitto_pub -h mintfv.peddy.net -p 1883 \
  -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-a/sensor01/test" -m "Hello"

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
