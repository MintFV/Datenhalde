# InfluxDB 3 Core

Time-Series Datenbank für Sensor-Daten, Metriken & Logs.

**Version:** 3.8.0 (influxdb:3-core)  
**Container:** mintfv-influxdb (UID 2005:2100)  
**URL:** https://mintfv.peddy.net/influxdb/ (API only)  
**Port:** 8181 (intern)  
**APIs:** v1 (InfluxQL), v2 (Compatibility), v3 (SQL)

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

## 🚀 Quick Start

### Status prüfen
```bash
docker compose ps influxdb
docker compose logs -f influxdb
```

### Admin Token auslesen
```bash
export INFLUX_TOKEN=$(cat ./influxdb/tokens/admin.token | jq -r '.token')
echo $INFLUX_TOKEN
```

---

## 📊 Datenbank-Operationen

### Datenbank erstellen
```bash
docker compose exec influxdb influxdb3 create database mydb
```

### Datenbanken auflisten
```bash
docker compose exec influxdb influxdb3 database list
```

### Datenbank löschen
```bash
docker compose exec influxdb influxdb3 database delete mydb
```

---

## ✍️ Daten schreiben

### Via CLI (Line Protocol)
```bash
docker compose exec influxdb influxdb3 write --database mydb \
  "temperature,location=room temp=23.5"
```

### Via HTTP API (v2 Compatibility)
```bash
export INFLUX_TOKEN=$(cat ./influxdb/tokens/admin.token | jq -r '.token')

curl -X POST "https://mintfv.peddy.net/influxdb/api/v2/write?bucket=mydb&org=InfluxDB" \
  -H "Authorization: Token $INFLUX_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-raw 'temperature,location=room temp=23.5'
```

### Via HTTP API (v1 InfluxQL)
```bash
curl -X POST "https://mintfv.peddy.net/influxdb/write?db=mydb" \
  -H "Authorization: Bearer $INFLUX_TOKEN" \
  -d 'temperature,location=room temp=23.5'
```

---

## 🔍 Daten abfragen

### SQL Query (v3)
```bash
docker compose exec influxdb influxdb3 query --database mydb \
  "SELECT * FROM temperature ORDER BY time DESC LIMIT 10"
```

### InfluxQL Query (v1)
```bash
curl "https://mintfv.peddy.net/influxdb/query?db=mydb&q=SELECT%20*%20FROM%20temperature%20LIMIT%2010" \
  -H "Authorization: Token $INFLUX_TOKEN"
```

### Via Grafana
Siehe [../grafana/README.md](../grafana/README.md) für Data Source Setup.

---

## 💾 Persistence & Backup

### Daten-Verzeichnis
```
./influxdb/
├── data/              # HAUPTDATEN - REGELMÄSSIG SICHERN!
│   ├── influxd.bolt   # Meta-Datenbank
│   ├── engine/        # Query Engine
│   └── mintfv-node-0/ # Node-Daten, WAL, Catalog
├── tokens/            # Admin Token (git-ignored)
└── plugins/           # Extensions
```

### Backup erstellen
```bash
# Stoppe InfluxDB
docker compose stop influxdb

# Backup erstellen
tar -czf influxdb-backup-$(date +%Y%m%d).tar.gz ./influxdb/data/

# Starte InfluxDB
docker compose start influxdb
```

### Restore
```bash
docker compose stop influxdb
rm -rf ./influxdb/data/*
tar -xzf influxdb-backup-YYYYMMDD.tar.gz
docker compose start influxdb
```

---

## 🧪 Health Check

### API Check
```bash
export INFLUX_TOKEN=$(cat ./influxdb/tokens/admin.token | jq -r '.token')

curl -fsS "https://mintfv.peddy.net/influxdb/health" | jq .
# Expected: {"status":"pass","version":"3.8.0"}
```

### Container Check
```bash
docker compose exec influxdb influxdb3 ping
# Expected: OK
```

---

## 🔗 Integration

### Grafana Data Source
```
Type: InfluxDB
URL: http://influxdb:8181
Query Language: SQL oder InfluxQL
Organization: InfluxDB
Token: [Admin Token]
Database: mydb
```

### Node-RED influxdb Node
```
URL: http://influxdb:8181
Version: 2.x (Compatibility Mode)
Token: [Admin Token]
Organization: InfluxDB
Bucket: mydb
```

### Python (influxdb-client)
```python
from influxdb_client_3 import InfluxDBClient3

client = InfluxDBClient3(
    host='mintfv.peddy.net',
    token='YOUR_ADMIN_TOKEN',
    database='mydb',
    org='InfluxDB'
)

# Write
client.write("temperature,location=room temp=23.5")

# Query
table = client.query("SELECT * FROM temperature LIMIT 10")
print(table)
```

---

## ⚠️ Troubleshooting

### Problem: Token nicht gefunden
```bash
# Token-Datei prüfen
cat ./influxdb/tokens/admin.token | jq .

# Token neu generieren (nur bei Problemen!)
# ⚠️ Alte Token werden ungültig!
# docker compose down influxdb
# rm ./influxdb/tokens/admin.token
# docker compose up -d influxdb
```

### Problem: Datenbank nicht erreichbar
```bash
# Container-Status
docker compose ps influxdb

# Logs
docker compose logs influxdb | tail -30

# Health Check
curl http://localhost:8181/health
```

### Problem: Keine Write-Permission
```bash
# Permissions prüfen
ls -la ./influxdb/data/

# Sollte UID 2005 gehören
sudo chown -R 2005:2100 ./influxdb/data/
```

---

## 📚 Weitere Informationen

- **Token:** `./influxdb/tokens/admin.token` (JSON, git-ignored)
- **Data:** `./influxdb/data/` (Backup wichtig!)
- **CLI:** [InfluxDB CLI Docs](https://docs.influxdata.com/influxdb/latest/reference/cli/)
- **Line Protocol:** [Syntax Reference](https://docs.influxdata.com/influxdb/latest/reference/syntax/line-protocol/)
- **Grafana:** [../grafana/README.md](../grafana/README.md)
