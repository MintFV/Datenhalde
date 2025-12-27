# InfluxDB 3 Core - Quick Reference

## Token Management

```bash
# Token auslesen
export ADMIN_TOKEN=$(sudo cat ./influxdb/tokens/admin.token | jq -r '.token')
echo $ADMIN_TOKEN
```

## Häufige Befehle

### Datenbank-Operationen

```bash
# Datenbanken auflisten
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show databases

# Datenbank erstellen
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 create database DBNAME

# Datenbank mit Retention erstellen
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 create database DBNAME --retention-period "30d"
```

### Daten schreiben

```bash
# Einzelner Datenpunkt
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 write --database DBNAME \
  "measurement,tag1=value1 field1=123.45"

# Via HTTP API (v1)
curl -i "https://mintfv.peddy.net/influxdb/write?db=DBNAME&precision=s" \
  --header "Authorization: Bearer $ADMIN_TOKEN" \
  --data-binary 'measurement,location=office temperature=23.5'
```

### Daten abfragen

```bash
# SQL Query
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 query --database DBNAME \
  "SELECT * FROM measurement ORDER BY time DESC LIMIT 10"

# InfluxQL via HTTP (v1)
curl --get "https://mintfv.peddy.net/influxdb/query" \
  --header "Authorization: Token $ADMIN_TOKEN" \
  --data-urlencode "db=DBNAME" \
  --data-urlencode "q=SELECT * FROM measurement LIMIT 10"
```

## Status & Monitoring

```bash
# Container Status
docker compose ps influxdb

# Health Check
curl -i https://mintfv.peddy.net/influxdb/health

# Logs
docker compose logs influxdb --tail=50

# System Info
docker compose exec -T -e INFLUXDB3_AUTH_TOKEN="$ADMIN_TOKEN" influxdb \
  influxdb3 show system summary
```

## Troubleshooting

```bash
# Container neu starten
docker compose restart influxdb

# Vollständiger Neustart
docker compose stop influxdb
docker compose rm -f influxdb
docker compose up -d influxdb

# Token-Datei prüfen
sudo cat ./influxdb/tokens/admin.token | jq .

# Permissions korrigieren
sudo chown -R 2005:2100 ./influxdb/data ./influxdb/tokens
sudo chmod 750 ./influxdb/data
sudo chmod 600 ./influxdb/tokens/admin.token
```

## Grafana Data Source

**InfluxQL (v1):**
- URL: `http://influxdb:8181`
- Database: `DBNAME`
- Password: `[ADMIN_TOKEN]`
- Query Language: `InfluxQL`

**Flux (v2 Compatibility):**
- URL: `http://influxdb:8181`
- Token: `[ADMIN_TOKEN]`
- Default Bucket: `DBNAME`
- Query Language: `Flux`

## Wichtige Pfade

- Admin Token: `./influxdb/tokens/admin.token`
- Daten: `./influxdb/data/`
- Plugins: `./influxdb/plugins/`
- Logs: `docker compose logs influxdb`

## Links

- Vollständige Dokumentation: [INFLUXDB.md](INFLUXDB.md)
- Docker Compose Config: [docker-compose.yaml](docker-compose.yaml)
- Offizielle Docs: https://docs.influxdata.com/influxdb3/core/
