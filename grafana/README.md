# Grafana

Visualization & Monitoring Platform für InfluxDB-Daten.

**Version:** Latest (grafana/grafana)  
**Container:** mintfv-grafana (UID 2006:2100)  
**URL:** https://mintfv.peddy.net/grafana/  
**Port:** 3000 (intern)  
**Demo-Login:** admin / admin

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

## 🚀 Quick Start

### 1. Login & Passwort ändern
```
1. Öffne https://mintfv.peddy.net/grafana/
2. Login: admin / admin
3. User Icon (unten links) → Profile → Change Password
```

### 2. InfluxDB Data Source hinzufügen
```
1. Configuration (Zahnrad) → Data Sources → Add data source
2. Wähle: InfluxDB
3. Konfiguration:
   - Name: InfluxDB
   - Query Language: SQL oder InfluxQL
   - URL: http://influxdb:8181
   - Custom HTTP Headers:
     * Header: Authorization
     * Value: Token [DEIN_ADMIN_TOKEN]
   - Organization: InfluxDB
   - Default Bucket: mydb
4. Save & Test
```

**Admin Token auslesen:**
```bash
cat ./influxdb/tokens/admin.token | jq -r '.token'
```

### 3. Erstes Dashboard erstellen
```
1. Dashboards (4 Quadrate) → New Dashboard
2. Add Visualization
3. Data Source: InfluxDB
4. Query Editor:
   - SQL: SELECT time, temp FROM temperature ORDER BY time DESC LIMIT 100
   - oder InfluxQL: SELECT mean(temp) FROM temperature GROUP BY time(5m)
5. Panel rechts: Titel, Einheit, Farben anpassen
6. Save Dashboard (💾 oben rechts)
```

---

## 📊 Query-Beispiele

### SQL (v3)
```sql
-- Letzte 24h Durchschnitt
SELECT 
  time_bucket('5m', time) as time,
  AVG(temperature) as avg_temp
FROM sensors
WHERE time >= now() - interval '24 hours'
GROUP BY time_bucket('5m', time)
ORDER BY time DESC
```

### InfluxQL (v1/v2)
```influxql
-- Durchschnitt über 5 Minuten
SELECT mean("temperature") 
FROM "sensors" 
WHERE time >= now() - 24h 
GROUP BY time(5m)
```

---

## 🎨 Dashboard-Tipps

### Panel-Typen
- **Time Series:** Linien-/Balken-Diagramme für Zeitreihen
- **Stat:** Einzelwert mit Trend
- **Gauge:** Mess-Anzeige (z.B. 0-100%)
- **Bar Chart:** Vergleich zwischen Kategorien
- **Table:** Tabellarische Daten

### Variables verwenden
```
1. Dashboard Settings (⚙️) → Variables → Add variable
2. Name: location
3. Query: SELECT DISTINCT location FROM sensors
4. In Panel Query: WHERE location = '$location'
```

### Alerting
```
1. Panel → Alert → Create alert rule
2. Condition: WHEN avg() OF query(A) IS ABOVE 30
3. Contact Point: Email/Slack/Telegram
4. Save
```

---

## 💾 Backup & Restore

### Dashboard JSON exportieren
```
1. Dashboard öffnen
2. Settings (⚙️) → JSON Model
3. Copy to Clipboard oder Download
```

### Dashboard importieren
```
1. Dashboards → New → Import
2. JSON einfügen oder .json hochladen
3. Data Source zuordnen
4. Import
```

### Komplettes Backup
```bash
# Datenbank exportieren
docker compose stop grafana
tar -czf grafana-backup-$(date +%Y%m%d).tar.gz ./grafana/data/
docker compose start grafana
```

### API-basiertes Backup (empfohlen)
```bash
# API Key erstellen: Configuration → API Keys

export GRAFANA_TOKEN="your_api_key"

# Alle Dashboards exportieren
curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
  https://mintfv.peddy.net/grafana/api/search | jq .

# Dashboard exportieren
curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
  https://mintfv.peddy.net/grafana/api/dashboards/uid/DASHBOARD_UID \
  > dashboard-backup.json
```

---

## 🔗 Integration

### InfluxDB Data Source (detailliert)
```
Name: InfluxDB
Type: InfluxDB
URL: http://influxdb:8181

Query Language: SQL
Custom HTTP Headers:
  Authorization: Token apiv3_XXXXXXXXXX

Organization: InfluxDB
Default Bucket: mydb

Min time interval: 1s
```

### Node-RED Dashboard
```
# Node-RED Flow → Grafana Annotation
[mqtt in] → [function] → [http request]

// Function:
msg.payload = {
  dashboardId: 1,
  panelId: 1,
  time: Date.now(),
  tags: ["sensor", "alert"],
  text: "Temperature spike detected"
};
msg.headers = {
  "Authorization": "Bearer YOUR_API_KEY"
};
msg.url = "http://grafana:3000/api/annotations";
return msg;
```

---

## ⚠️ Troubleshooting

### Problem: Dashboard zeigt keine Daten
```bash
# 1. Data Source testen
Configuration → Data Sources → InfluxDB → Test

# 2. Query manuell prüfen
Query Inspector (Panel → ⋮ → Inspect → Query)

# 3. InfluxDB Logs
docker compose logs influxdb | grep ERROR
```

### Problem: Login funktioniert nicht
```bash
# Admin-Passwort zurücksetzen
docker compose exec grafana grafana-cli admin reset-admin-password newpassword

# Container neu starten
docker compose restart grafana
```

### Problem: Grafana nicht erreichbar
```bash
# Container-Status
docker compose ps grafana

# Logs
docker compose logs grafana | tail -20

# Neu starten
docker compose restart grafana
```

---

## 🔒 Sicherheit

### API Key erstellen (für Automation)
```
1. Configuration → API Keys → New API Key
2. Role: Viewer (read-only) oder Editor
3. Time to live: Optional
4. Add
```

### Benutzer hinzufügen
```
1. Configuration → Users → Invite
2. Email oder Username
3. Role: Viewer / Editor / Admin
4. Send Invite
```

### Authentication via OAuth (optional)
Siehe [Grafana OAuth Docs](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/)

---

## 📚 Weitere Informationen

- **Config:** Container-Environment in `docker-compose.yaml`
- **Data:** `./grafana/data/grafana.db` (SQLite, git-ignored)
- **Plugins:** `./grafana/data/plugins/`
- **Docs:** [Grafana Docs](https://grafana.com/docs/grafana/)
- **InfluxDB Plugin:** [Data Source Docs](https://grafana.com/docs/grafana/latest/datasources/influxdb/)
- **InfluxDB Integration:** [../influxdb/README.md](../influxdb/README.md)
