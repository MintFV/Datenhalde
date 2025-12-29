# Grafana - Architektur-Übersicht

**Version:** Latest (grafana/grafana)  
**Container:** mintfv-grafana (UID 2006:2100)  
**URL:** https://mintfv.peddy.net/grafana/  
**Port:** 3000 (intern)

> 📖 **Vollständige Dokumentation:** [grafana/README.md](grafana/README.md)

---

## 🏗️ Architektur

### Datenfluss
```
InfluxDB → Grafana → Dashboard
  ├─ Data Source: http://influxdb:8181
  ├─ Query: SQL oder InfluxQL
  └─ Visualization: Time Series, Stat, Gauge, etc.
```

### Konfiguration
```
grafana/
└── data/
    ├── grafana.db         # SQLite (Dashboards, Users, Settings)
    ├── plugins/           # Installierte Plugins
    └── csv/, pdf/, png/   # Exports
```

---

## 🔑 Authentifizierung

**Demo-Login:** admin / admin (⚠️ Nach Login ändern!)

```bash
# Admin-Passwort zurücksetzen
docker compose exec grafana grafana-cli admin reset-admin-password newpassword

# In .env setzen
GF_SECURITY_ADMIN_PASSWORD=newpassword
```

---

## 📊 InfluxDB Data Source

### Setup
```
1. Configuration → Data Sources → Add InfluxDB
2. URL: http://influxdb:8181
3. Custom HTTP Headers:
   - Header: Authorization
   - Value: Token [ADMIN_TOKEN]
4. Organization: InfluxDB
5. Default Bucket: mydb
```

**Admin Token auslesen:**
```bash
cat ./influxdb/tokens/admin.token | jq -r '.token'
```

---

## 🚀 Quick Start

```bash
# Status prüfen
docker compose ps grafana
docker compose logs -f grafana

# Zugriff
https://mintfv.peddy.net/grafana/

# Health Check
curl -u admin:admin https://mintfv.peddy.net/grafana/api/health
```

---

## 📚 Weitere Informationen

- **Setup & Data Sources:** [grafana/README.md](grafana/README.md)
- **Query-Beispiele:** [grafana/README.md#-query-beispiele](grafana/README.md#-query-beispiele)
- **Dashboard-Tipps:** [grafana/README.md#-dashboard-tipps](grafana/README.md#-dashboard-tipps)
- **Backup:** [grafana/README.md#-backup--restore](grafana/README.md#-backup--restore)
- **Upstream Docs:** [Grafana](https://grafana.com/docs/grafana/)
