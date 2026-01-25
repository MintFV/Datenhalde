# Grafana Alerting Provisioning

Automatische Konfiguration von Grafana Alerting via Dateien (Infrastructure as Code).

## 📁 Struktur

```
provisioning/alerting/
├── README.md                           # Diese Datei
├── email-contact-point-example.yaml   # Email Contact Point (Beispiel, deaktiviert)
└── (weitere Alert-Regeln hier)
```

## 🚀 Email Contact Point aktivieren

### Schritt 1: Beispiel-Datei anpassen

```bash
cd grafana/provisioning/alerting/
vi email-contact-point-example.yaml
```

**Anpassungen:**
```yaml
apiVersion: 1  # Von 0 auf 1 ändern
contactPoints:
  - orgId: 1
    name: email-notifications
    receivers:
      - uid: email-notifications-uid
        type: email
        settings:
          addresses: deine@email.de  # HIER ANPASSEN!
```

### Schritt 2: Grafana neu starten

```bash
cd /home/peddy/mintfv
docker compose restart grafana
```

### Schritt 3: Überprüfen

```
1. Öffne Grafana: https://mintfv.peddy.net/grafana/
2. Alerting → Contact points
3. "email-notifications" sollte vorhanden sein
4. Test → Send test notification
```

## 📧 Test-Email senden

```bash
# Via MintFV Script
./mintfv.sh test-email deine@email.de

# Via Grafana UI
Alerting → Contact points → email-notifications → Test
```

## 🔧 Alert Rules erstellen

**Provisioning-Beispiel** (alert-rule-example.yaml):

```yaml
apiVersion: 1
groups:
  - orgId: 1
    name: example-alerts
    folder: Alerts
    interval: 1m
    rules:
      - uid: example-alert-uid
        title: Example Alert
        condition: A
        data:
          - refId: A
            queryType: ""
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: influxdb-uid  # Deine InfluxDB Data Source UID
            model:
              query: "SELECT mean(temperature) FROM sensors"
        noDataState: NoData
        execErrState: Error
        for: 5m
        annotations:
          description: "Temperature exceeded threshold"
        labels:
          severity: warning
        isPaused: false
```

## 🛠️ Manuelle Konfiguration (Alternative)

Wenn Provisioning zu komplex ist, nutze die Grafana UI:

```
1. Alerting → Alert rules → + New alert rule
2. Konfiguriere Query, Bedingung, Contact Point
3. Save
```

**Vorteile UI:**
- Visueller Query Builder
- Sofortiges Feedback
- Einfacher für Einsteiger

**Vorteile Provisioning:**
- Versionskontrolle (Git)
- Automatische Wiederherstellung
- Multi-Environment Deployment

## 📚 Dokumentation

- **Grafana Alerting:** https://grafana.com/docs/grafana/latest/alerting/
- **Provisioning:** https://grafana.com/docs/grafana/latest/administration/provisioning/
- **Contact Points:** https://grafana.com/docs/grafana/latest/alerting/manage-notifications/
- **Email Setup:** [../README.md#email-notifications](../README.md#email-notifications)

## 🔍 Troubleshooting

**Contact Point wird nicht erstellt:**
```bash
# Logs prüfen
docker compose logs grafana | grep -i provision

# apiVersion = 1?
grep apiVersion email-contact-point-example.yaml

# Neu starten
docker compose restart grafana
```

**Test-Email kommt nicht an:**
```bash
# SMTP-Relay prüfen
docker compose logs smtp-relay --tail 50

# Test via Script
./mintfv.sh test-email deine@email.de
```

Siehe auch: [../../README.md](../../README.md) für SMTP-Relay Konfiguration
