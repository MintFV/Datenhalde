# Node-RED - Architektur-Übersicht

**Version:** Latest (nodered/node-red)  
**Container:** mintfv-nodered (UID 2004:2100)  
**URL:** https://mintfv.peddy.net/nodered/  
**Port:** 1880 (intern)

> 📖 **Vollständige Dokumentation:** [nodered/README.md](nodered/README.md)

---

## 🏗️ Architektur

### Datenfluss
```
MQTT → Node-RED → InfluxDB
  ├─ Subscribe: tenant/+/+/+
  ├─ Processing: Flows
  └─ Write: Line Protocol
```

### Konfiguration
```
nodered/
└── data/
    ├── settings.js         # Admin Auth, Context Storage
    ├── flows.json          # Flow-Definitionen (git-ignored)
    ├── package.json        # Installierte Nodes
    └── context/            # Persistente Variablen
```

---

## 🔐 Authentifizierung

**Setup:** Siehe [nodered/README.md#-authentifizierung-aktivieren](nodered/README.md#-authentifizierung-aktivieren)

```bash
# 1. Hash generieren
docker compose exec nodered npx node-red admin hash-pw

# 2. In .env eintragen
NODE_RED_ADMIN_PASSWORD_HASH='$2y$08$...'

# 3. Container neu starten
docker compose restart nodered
```

---

## 📊 Integration

### MQTT → Node-RED
```
MQTT In Node:
- Server: mosquitto:1883
- Topic: tenant/tenant-a/sensor01/+
- Username: tenant-a-nodered
- Password: nodered-a
```

### Node-RED → InfluxDB
```
InfluxDB Out Node:
- URL: http://influxdb:8181
- Token: [siehe influxdb/tokens/admin.token]
- Bucket: mintfv
```

---

## 🚀 Quick Start

```bash
# Status prüfen
docker compose ps nodered
docker compose logs -f nodered

# Zugriff
https://mintfv.peddy.net/nodered/

# Nodes installieren
Menu → Manage Palette → Install → node-red-contrib-influxdb
```

---

## 📚 Weitere Informationen

- **Setup & Auth:** [nodered/README.md](nodered/README.md)
- **InfluxDB Integration:** [nodered/README.md#-influxdb-integration](nodered/README.md#-influxdb-integration)
- **MQTT Integration:** [nodered/README.md#-mqtt-integration](nodered/README.md#-mqtt-integration)
- **Troubleshooting:** [nodered/README.md#-troubleshooting](nodered/README.md#-troubleshooting)
- **Upstream Docs:** [Node-RED](https://nodered.org/docs/)
