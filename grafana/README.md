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
├── data/
│   ├── grafana.db         # SQLite (Dashboards, Users, Settings)
│   ├── plugins/           # Installierte Plugins
│   └── csv/, pdf/, png/   # Exports
├── provisioning/          # Automatic configuration
│   ├── datasources/       # Auto-configure InfluxDB
│   ├── dashboards/        # Auto-import providers
│   └── alerting/          # Email contact points
└── dashboards/            # Dashboard JSON files
    └── *.json             # Auto-imported on startup
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
   - Name: InfluxDB-MintFV
   - Query Language: SQL
   - URL: http://influxdb:8181
   - InfluxDB Details
      - Database: mintfv
      - Token: <kommt via .env>
      - Insecure Connection: true
4. Save & Test
```

**influxdb Admin Token auslesen:**
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

## � Provisioning (Automatic Setup)

Grafana ist bereits für automatisches Setup konfiguriert. Beim Container-Start werden automatisch geladen:

### Data Sources (InfluxDB)

**File:** `grafana/provisioning/datasources/influxdb.yaml`

```yaml
apiVersion: 1
datasources:
  - name: InfluxDB-MintFV
    type: influxdb
    url: http://influxdb:8181
    jsonData:
      version: SQL
      dbName: mintfv
    isDefault: true
    secureJsonData:
      token: ${INFLUXDB_TOKEN}  # From .env
```

✅ **Data Source ist automatisch verfügbar** - kein manuelles Setup nötig!

### Dashboards

**Provider Config:** `grafana/provisioning/dashboards/default.yaml`

```yaml
apiVersion: 1
providers:
  - name: 'MintFV Dashboards'
    folder: 'MintFV'
    type: file
    updateIntervalSeconds: 10  # Auto-reload every 10s
    allowUiUpdates: true       # UI changes allowed
    options:
      path: /etc/grafana/dashboards
```

**Dashboard Files:** `grafana/dashboards/*.json`

```
grafana/dashboards/
└── umweltbox-cpu-v5.json  # Example dashboard (auto-imported)
```

✅ **Dashboards werden automatisch importiert** aus `grafana/dashboards/`!

### Alerting (Email)

**Example:** `grafana/provisioning/alerting/email-contact-point-example.yaml`

Details siehe [Email Notifications](#-email-notifications) weiter unten.

### Neues Dashboard hinzufügen

**Methode 1: JSON-File kopieren** (empfohlen)

```bash
# Dashboard in Grafana UI erstellen & exportieren
# Dashboard Settings (⚙️) → JSON Model → Copy

# JSON speichern
cat > grafana/dashboards/my-dashboard.json <<EOF
{
  "title": "My Dashboard",
  "panels": [...]
}
EOF

# Grafana lädt automatisch nach ~10 Sekunden
# Oder Container neu starten:
docker compose restart grafana
```

**Methode 2: Via Docker Copy**

```bash
# Dashboard aus Container exportieren
docker compose exec grafana cat /var/lib/grafana/grafana.db > backup.db

# Oder via API (siehe Backup & Restore)
```

### Provisioning deaktivieren

Falls du manuelle Konfiguration bevorzugst:

```yaml
# docker-compose.yaml - Volumes auskommentieren:
volumes:
  - ./grafana/data:/var/lib/grafana:rw
  # - ./grafana/provisioning:/etc/grafana/provisioning:rw
  # - ./grafana/dashboards:/etc/grafana/dashboards:ro
```

---

## �📊 Query-Beispiele

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

## � Email Notifications

Grafana ist bereits für Email-Versand via SMTP-Relay konfiguriert.

### SMTP-Konfiguration (bereits aktiv)

```yaml
GF_SMTP_ENABLED: true
GF_SMTP_HOST: smtp-relay:8025
GF_SMTP_FROM_ADDRESS: mintfv@example.com
```

**Der SMTP-Relay leitet Emails über smtp.ionos.de:587 weiter.**

### Test-Email senden

#### Methode 1: Via MintFV Management Script (ohne Grafana UI)

```bash
# Interaktiv (fragt nach Empfänger)
./mintfv.sh test-email

# Mit Empfänger-Parameter
./mintfv.sh test-email user@example.com
```

#### Methode 2: Via Grafana UI

```
1. Alerting (Glockensymbol) → Contact points
2. + New contact point
3. Name: Email Notifications
4. Integration: Email
5. Addresses: deine@email.de (komma-separiert für mehrere)
6. Optional: Message Templates anpassen
7. Test → Send test notification
8. Save contact point
```

### Alert Rule mit Email erstellen

**Schritt 1: Contact Point erstellen** (siehe oben)

**Schritt 2: Alert Rule anlegen**

```
1. Alerting → Alert rules → + New alert rule
2. Rule name: z.B. "High Temperature Alert"
3. Data source: InfluxDB-MintFV
4. Query: SELECT temperature FROM sensors WHERE location='garden'
5. Expression: WHEN last() > 30  (Beispiel: Temperatur über 30°C)
6. Evaluation interval: 1m
7. Pending period: 5m (verhindert Spam bei kurzen Spikes)
8. Contact point: Email Notifications
9. Save rule
```

**Schritt 3: Notification Policy (optional)**

```
Alerting → Notification policies
├─ Root policy (default)
│  ├─ Contact point: Email Notifications
│  ├─ Group by: alertname, grafana_folder
│  └─ Timings:
│     ├─ Group wait: 30s
│     ├─ Group interval: 5m
│     └─ Repeat interval: 4h
```

### Troubleshooting

**Email kommt nicht an?**

```bash
# 1. SMTP-Relay Logs prüfen
docker compose logs smtp-relay --tail 50

# 2. Grafana Logs prüfen
docker compose logs grafana | grep -i smtp

# 3. Test-Email senden
./mintfv.sh test-email deine@email.de

# 4. Spam-Ordner checken!
```

**Häufige Fehler:**

- **"Email address not allowed"** → Domain nicht in `RELAY_TO_DOMAINS` (docker-compose.yaml)
- **"Connection refused"** → smtp-relay Container läuft nicht: `docker compose ps smtp-relay`
- **"Authentication failed"** → SMTP-Credentials in `.env.smtp.password` prüfen
- **Keine Error, aber Email fehlt** → Spam-Ordner, Graylisting (15min warten)

**Erlaubte Email-Domains** (konfiguriert im smtp-relay):

- *.net,*.com, *.org,*.de

**Andere Domain hinzufügen:**

```yaml
# In docker-compose.yaml beim smtp-relay Service:
RELAY_TO_DOMAINS: "*.net:*.com:*.org:*.de:*.eu"  # *.eu hinzugefügt
```

### Email-Templates anpassen

Grafana verwendet Go-Templates für Email-Benachrichtigungen:

```
{{ define "custom_email" }}
{{ range .Alerts }}
Alert: {{ .Labels.alertname }}
Status: {{ .Status }}
Value: {{ .Values }}
{{ end }}
{{ end }}
```

Siehe: [Grafana Notification Templates](https://grafana.com/docs/grafana/latest/alerting/manage-notifications/template-notifications/)

---

## �🔒 Sicherheit

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
