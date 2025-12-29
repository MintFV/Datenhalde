# InfluxDB 3 Core - Architektur-Übersicht

**Version:** 3.8.0 (influxdb:3-core)  
**Container:** mintfv-influxdb (UID 2005:2100)  
**URL:** https://mintfv.peddy.net/influxdb/ (API only)  
**Port:** 8181 (intern)

> 📖 **Vollständige Dokumentation:** [influxdb/README.md](influxdb/README.md)

---

## 🏗️ Architektur

### APIs
- **v3 (SQL):** Native InfluxDB 3 Query Language
- **v2 (Compatibility):** InfluxQL für Migration
- **v1 (Legacy):** Line Protocol Write

### Datenstruktur
```
influxdb/
├── data/
│   ├── influxd.bolt       # Meta-Datenbank
│   ├── engine/            # Query Engine
│   └── mintfv-node-0/     # Node-Daten
│       ├── wal/           # Write-Ahead Log
│       └── catalog/       # Table Metadata
├── tokens/
│   └── admin.token        # Admin Token (JSON, git-ignored)
└── plugins/               # Extensions
```

---

## 🔑 Authentifizierung

**Admin Token:**
```bash
# Token auslesen
cat ./influxdb/tokens/admin.token | jq -r '.token'

# Verwendung
curl -H "Authorization: Bearer $TOKEN" \
  https://mintfv.peddy.net/influxdb/health
```

---

## 📊 Datenoperationen

### Schreiben (Line Protocol)
```bash
# Via CLI
docker compose exec influxdb influxdb3 write --database mydb \
  "temperature,location=room temp=23.5"

# Via HTTP API
curl -X POST "https://mintfv.peddy.net/influxdb/write?db=mydb" \
  -H "Authorization: Bearer $TOKEN" \
  -d 'temperature,location=room temp=23.5'
```

### Abfragen (SQL)
```bash
# Via CLI
docker compose exec influxdb influxdb3 query --database mydb \
  "SELECT * FROM temperature ORDER BY time DESC LIMIT 10"
```

---

## 🚀 Quick Start

```bash
# Status prüfen
docker compose ps influxdb
docker compose logs -f influxdb

# Token auslesen
export INFLUX_TOKEN=$(cat ./influxdb/tokens/admin.token | jq -r '.token')

# Datenbank erstellen
docker compose exec influxdb influxdb3 create database mydb

# Health Check
curl -fsS https://mintfv.peddy.net/influxdb/health | jq .
```

---

## 📚 Weitere Informationen

- **Setup & Token:** [influxdb/README.md](influxdb/README.md)
- **Datenbank-Operationen:** [influxdb/README.md#-datenbank-operationen](influxdb/README.md#-datenbank-operationen)
- **Grafana Integration:** [grafana/README.md](grafana/README.md)
- **Backup:** [influxdb/README.md#-persistence--backup](influxdb/README.md#-persistence--backup)
- **Upstream Docs:** [InfluxDB 3](https://docs.influxdata.com/influxdb/latest/)
