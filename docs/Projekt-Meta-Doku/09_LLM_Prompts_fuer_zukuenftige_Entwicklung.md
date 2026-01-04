# Umweltbox - LLM-Prompts für zukünftige Entwicklung

## 🤖 Zweck dieser Dokumentation

Diese Datei enthält **fertige Prompts für Large Language Models (LLMs)**, um die Weiterentwicklung des Umweltbox-Projekts zu beschleunigen. Die Prompts sind so formuliert, dass sie:

- **Kontext** über das Projekt liefern
- **Spezifische Aufgaben** klar definieren
- **Best Practices** aus den bisherigen Dokumenten berücksichtigen
- **Code-Beispiele** generieren, die direkt verwendbar sind

**Zielgruppe**: Entwickler*innen, DevOps-Engineers, Lehrkräfte

---

## 📋 Prompt-Kategorien

1. [Hardware & Firmware](#1-hardware--firmware)
2. [MQTT & Node-RED](#2-mqtt--node-red)
3. [InfluxDB & Datenmodellierung](#3-influxdb--datenmodellierung)
4. [Grafana Dashboards](#4-grafana-dashboards)
5. [Security & Monitoring](#5-security--monitoring)
6. [Onboarding & Dokumentation](#6-onboarding--dokumentation)
7. [Troubleshooting & Debugging](#7-troubleshooting--debugging)

---

## 1. Hardware & Firmware

### 1.1 Tasmota-Konfiguration für neuen Sensor

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt, einer Multi-Tenant-IoT-Plattform für Schulen.
Wir verwenden ESP8266/ESP32 mit Tasmota-Firmware und MQTT.

Aufgabe:
Erstelle eine Tasmota-Konfiguration für einen [SENSOR-NAME, z.B. "BMP280 Luftdrucksensor"].

Anforderungen:
- MQTT-Topic-Struktur: umweltbox/{tenant}/{device}/{category}/{sensor_type}
- Payload-Format: JSON mit "value", "unit", "timestamp"
- WiFi-Konfiguration über Captive Portal
- TLS-verschlüsselte MQTT-Verbindung (Port 8883)
- Gerät soll alle 5 Minuten Daten senden

Kontext:
- Tenant: de-hh-gs-altona (Grundschule Altona, Hamburg)
- Device-ID: esp-klassenraum-3b
- MQTT-Broker: mqtt.umweltbox.de
- Authentifizierung: Username/Password (ACL-basiert)

Bitte liefere:
1. Tasmota Console-Befehle für die Konfiguration
2. Beispiel-MQTT-Payload
3. Rule für automatisches Senden alle 5 Minuten
```

**Erwartetes Output**:
```
Backlog MqttHost mqtt.umweltbox.de; MqttPort 8883; MqttUser de-hh-gs-altona-esp01; MqttPassword SECRET; MqttClient esp-klassenraum-3b; Topic umweltbox/de-hh-gs-altona/esp-klassenraum-3b

Rule1 ON Tele-BMP280#Pressure DO Publish umweltbox/de-hh-gs-altona/esp-klassenraum-3b/environment/pressure {"value": %value%, "unit": "hPa", "timestamp": "%timestamp%"} ENDON
```

---

### 1.2 Raspberry Pi als MQTT-Gateway

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen einen Raspberry Pi als Gateway für Sensoren nutzen, die nicht direkt WiFi haben (z.B. USB-Sensoren, I2C-Sensoren).

Aufgabe:
Erstelle ein Python-Script, das:
1. Daten von einem [SENSOR-NAME, z.B. "SDS011 Feinstaubsensor via USB"] ausliest
2. Daten via MQTT an unseren Broker sendet
3. TLS-verschlüsselt kommuniziert
4. Automatisch als systemd-Service läuft

MQTT-Konfiguration:
- Broker: mqtt.umweltbox.de:8883
- Topic: umweltbox/{tenant}/{device}/air_quality/pm25
- Payload: {"value": 12.5, "unit": "µg/m³", "timestamp": "2025-01-03T15:00:00Z"}
- Auth: Username/Password

Bitte liefere:
1. Python-Script (mit paho-mqtt)
2. systemd-Service-Datei
3. Installations-Anleitung
```

---

### 1.3 Tasmota-Template für Custom-Hardware

**Prompt**:
```
Ich habe einen ESP8266 mit folgenden Sensoren:
- DHT22 (Temperatur/Luftfeuchtigkeit) an GPIO4
- BMP280 (Luftdruck) an I2C (GPIO14=SDA, GPIO12=SCL)
- LED-Anzeige an GPIO2

Erstelle ein Tasmota-Template für diese Hardware-Konfiguration.

Anforderungen:
- Template soll über Tasmota Web-UI importierbar sein
- Alle Sensoren sollen automatisch erkannt werden
- LED soll bei MQTT-Verbindungsverlust blinken
```

---

## 2. MQTT & Node-RED

### 2.1 Node-RED Flow für Datenvalidierung

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir nutzen Node-RED zur Datenverarbeitung zwischen MQTT und InfluxDB.

Aufgabe:
Erstelle einen Node-RED Flow, der:
1. MQTT-Nachrichten von Topic "umweltbox/+/+/environment/temperature" empfängt
2. Daten validiert (Temperatur zwischen -40°C und 80°C)
3. Ungültige Werte verwirft und in separate "errors"-Bucket schreibt
4. Gültige Werte an InfluxDB weiterleitet

Payload-Format:
{"value": 23.5, "unit": "°C", "timestamp": "2025-01-03T15:00:00Z"}

InfluxDB-Konfiguration:
- Bucket: umweltbox
- Measurement: umweltbox
- Tags: tenant_id, device_id, sensor_type
- Field: value

Bitte liefere:
1. Node-RED Flow (JSON)
2. Erklärung der einzelnen Nodes
```

---

### 2.2 MQTT-ACL-Generator

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir nutzen Mosquitto mit ACL-basierter Zugriffskontrolle.

Aufgabe:
Erstelle ein Bash-Script, das automatisch ACL-Einträge generiert für:
- Neue Tenants (Schulen)
- Neue Geräte (ESP8266/Raspberry Pi)

Anforderungen:
- Tenant darf nur auf eigene Topics zugreifen: umweltbox/{tenant}/#
- Geräte dürfen nur auf eigene Topics schreiben: umweltbox/{tenant}/{device}/#
- Admin-User darf alles lesen: umweltbox/#

ACL-Format (Mosquitto):
user tenant-user
topic write umweltbox/tenant-id/#
topic read umweltbox/tenant-id/#

Bitte liefere:
1. Bash-Script für ACL-Generierung
2. Beispiel-Aufruf
```

---

### 2.3 MQTT-Monitoring mit Telegraf

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen unseren MQTT-Broker (Mosquitto) monitoren.

Aufgabe:
Erstelle eine Telegraf-Konfiguration, die:
1. Mosquitto-Metriken sammelt (via $SYS-Topics)
2. Daten an InfluxDB sendet
3. Folgende Metriken erfasst:
   - Anzahl verbundener Clients
   - Nachrichten pro Sekunde
   - Bytes gesendet/empfangen
   - Anzahl Subscriptions

Bitte liefere:
1. telegraf.conf (Auszug)
2. Flux-Query für Grafana-Dashboard
```

---

## 3. InfluxDB & Datenmodellierung

### 3.1 Downsampling-Task erstellen

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir speichern Sensordaten in InfluxDB und wollen alte Daten automatisch aggregieren (Downsampling).

Aufgabe:
Erstelle eine InfluxDB Task, die:
1. Rohdaten (1-Minuten-Intervall) nach 7 Tagen auf Stundenwerte aggregiert
2. Stundenwerte nach 90 Tagen auf Tageswerte aggregiert
3. Folgende Aggregationen berechnet: mean, min, max, stddev
4. Daten in separate Buckets schreibt: umweltbox_hourly, umweltbox_daily

Measurement: umweltbox
Tags: tenant_id, device_id, sensor_type
Field: value

Bitte liefere:
1. InfluxDB Task (Flux)
2. Erklärung der Aggregations-Logik
```

---

### 3.2 Datenqualitäts-Check

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen die Datenqualität unserer Sensoren überwachen.

Aufgabe:
Erstelle eine Flux-Query, die:
1. Geräte findet, die seit >1 Stunde keine Daten gesendet haben
2. Geräte findet, die unrealistische Werte senden (z.B. Temperatur >100°C)
3. Ergebnis als Tabelle ausgibt: device_id, last_seen, issue

Bitte liefere:
1. Flux-Query
2. Grafana-Alert-Konfiguration (optional)
```

---

### 3.3 Daten-Export für Wissenschaft

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Eine Universität möchte unsere Daten für eine Studie nutzen.

Aufgabe:
Erstelle ein Python-Script, das:
1. Daten aus InfluxDB exportiert (Zeitraum: letztes Jahr)
2. Format: CSV mit Spalten: timestamp, tenant_id, device_id, sensor_type, value, unit
3. Anonymisierung: device_id wird gehasht (SHA256)
4. Komprimierung: ZIP-Archiv

Bitte liefere:
1. Python-Script (mit influxdb-client)
2. Beispiel-Aufruf
```

---

## 4. Grafana Dashboards

### 4.1 Dashboard für Schul-Übersicht

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen ein Grafana-Dashboard für Schulen erstellen.

Aufgabe:
Erstelle ein Dashboard mit:
1. GeoMap: Alle Geräte der Schule auf Karte
2. Time-Series: Temperaturverlauf (letzte 24h)
3. Stat-Panel: Aktuelle Durchschnittswerte (Temperatur, Luftfeuchtigkeit, CO2)
4. Table: Liste aller Geräte mit letztem Messwert

Variablen:
- $tenant (Dropdown: Schul-Auswahl)

Flux-Query-Beispiel:
from(bucket: "umweltbox")
  |> range(start: -24h)
  |> filter(fn: (r) => r.tenant_id == "${tenant}")

Bitte liefere:
1. Dashboard-JSON (Auszug)
2. Erklärung der Panels
```

---

### 4.2 Alert-Konfiguration

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen Alarme bei kritischen Werten einrichten.

Aufgabe:
Erstelle eine Grafana-Alert-Regel, die:
1. Alarm auslöst, wenn CO2 > 1000 ppm für >15 Minuten
2. Benachrichtigung per E-Mail an Schulleitung
3. Alarm automatisch zurücksetzt, wenn CO2 < 800 ppm

Bitte liefere:
1. Alert-Konfiguration (JSON oder YAML)
2. Notification-Channel-Konfiguration
```

---

### 4.3 Public Dashboard (Anonymous Access)

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen ein öffentliches Dashboard erstellen, das jeder ohne Login sehen kann.

Aufgabe:
Erstelle eine Grafana-Konfiguration für:
1. Anonymous Access aktivieren (Read-Only)
2. Dashboard mit Live-Karte (alle Geräte bundesweit)
3. Embedding in externe Webseiten erlauben

Bitte liefere:
1. grafana.ini (Auszug)
2. HTML-Code für Embedding
```

---

## 5. Security & Monitoring

### 5.1 TLS-Zertifikat-Erneuerung automatisieren

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir nutzen Let's Encrypt für TLS-Zertifikate (MQTT, Grafana).

Aufgabe:
Erstelle ein Bash-Script, das:
1. Zertifikate via certbot erneuert
2. Mosquitto und Grafana automatisch neu startet
3. Als cronjob läuft (monatlich)
4. Benachrichtigung bei Fehler (E-Mail)

Bitte liefere:
1. Bash-Script
2. Crontab-Eintrag
```

---

### 5.2 Intrusion Detection (MQTT-Anomalien)

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen verdächtige MQTT-Aktivitäten erkennen.

Aufgabe:
Erstelle ein Python-Script, das:
1. MQTT-Logs analysiert (Mosquitto)
2. Anomalien erkennt:
   - Zu viele Verbindungsversuche (>100/Minute)
   - Unbekannte Client-IDs
   - Zugriff auf fremde Topics
3. Alerts per E-Mail sendet

Bitte liefere:
1. Python-Script
2. Beispiel-Log-Eintrag
```

---

### 5.3 Backup-Strategie für InfluxDB

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen tägliche Backups von InfluxDB erstellen.

Aufgabe:
Erstelle ein Bash-Script, das:
1. InfluxDB-Backup erstellt (influx backup)
2. Backup komprimiert (tar.gz)
3. Auf Remote-Server hochlädt (rsync oder S3)
4. Alte Backups löscht (>30 Tage)
5. Als cronjob läuft (täglich 02:00 Uhr)

Bitte liefere:
1. Bash-Script
2. Restore-Anleitung
```

---

## 6. Onboarding & Dokumentation

### 6.1 Onboarding-Wizard (Web-UI)

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen einen Web-basierten Onboarding-Wizard für neue Schulen.

Aufgabe:
Erstelle ein HTML-Formular mit:
1. Schritt 1: Schuldaten (Name, Adresse, Kontakt)
2. Schritt 2: Geräte-Registrierung (Anzahl, Typ)
3. Schritt 3: MQTT-Credentials generieren
4. Schritt 4: Tasmota-Konfiguration als Download

Backend:
- Python (Flask oder FastAPI)
- Datenbank: PostgreSQL
- API-Endpoint: POST /api/onboarding

Bitte liefere:
1. HTML-Formular (mit Validierung)
2. Python-Backend (Auszug)
```

---

### 6.2 Automatische Dokumentations-Generierung

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen eine Übersicht aller registrierten Geräte als PDF generieren.

Aufgabe:
Erstelle ein Python-Script, das:
1. Daten aus Device-Registry (PostgreSQL) holt
2. PDF generiert mit:
   - Tenant-Übersicht (Schulen)
   - Geräte-Liste (ID, Typ, Standort)
   - Statistiken (Anzahl Geräte, letzte Aktivität)
3. PDF per E-Mail an Admin sendet

Bitte liefere:
1. Python-Script (mit reportlab)
2. SQL-Query für Daten-Extraktion
```

---

### 6.3 FAQ-Generator aus Logs

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Wir wollen häufige Probleme aus Support-Tickets automatisch in eine FAQ umwandeln.

Aufgabe:
Erstelle ein Python-Script, das:
1. Support-Tickets aus Datenbank holt
2. Häufigste Probleme identifiziert (z.B. "MQTT-Verbindung fehlgeschlagen")
3. Markdown-FAQ generiert

Bitte liefere:
1. Python-Script
2. Beispiel-FAQ-Eintrag
```

---

## 7. Troubleshooting & Debugging

### 7.1 MQTT-Verbindung debuggen

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Ein ESP8266 kann sich nicht mit dem MQTT-Broker verbinden.

Aufgabe:
Erstelle eine Checkliste und Debug-Befehle für:
1. Netzwerk-Konnektivität prüfen (ping, traceroute)
2. TLS-Zertifikat validieren (openssl s_client)
3. MQTT-Credentials testen (mosquitto_pub)
4. Tasmota-Logs analysieren

Bitte liefere:
1. Schritt-für-Schritt-Anleitung
2. Beispiel-Befehle
```

---

### 7.2 InfluxDB Performance-Analyse

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. InfluxDB-Queries sind langsam (>10 Sekunden).

Aufgabe:
Erstelle eine Flux-Query, die:
1. Cardinality (Anzahl unique Tags) analysiert
2. Größte Measurements findet
3. Empfehlungen für Optimierung gibt

Bitte liefere:
1. Flux-Query für Cardinality-Check
2. Tipps für Performance-Optimierung
```

---

### 7.3 Grafana-Dashboard lädt nicht

**Prompt**:
```
Ich arbeite am Umweltbox-Projekt. Ein Grafana-Dashboard lädt nicht (Timeout).

Aufgabe:
Erstelle eine Debug-Checkliste:
1. InfluxDB-Query testen (influx CLI)
2. Grafana-Logs analysieren
3. Query-Performance optimieren

Bitte liefere:
1. Debug-Befehle
2. Beispiel für Query-Optimierung
```

---

## 🎯 Prompt-Templates für eigene Erweiterungen

### Template 1: Neue Sensor-Integration

```
Ich arbeite am Umweltbox-Projekt. Wir wollen einen neuen Sensor integrieren: [SENSOR-NAME].

Sensor-Details:
- Hersteller: [...]
- Schnittstelle: [I2C/SPI/UART/Analog]
- Messwerte: [z.B. "CO2 in ppm"]
- Datenblatt: [URL]

Aufgabe:
1. Tasmota-Konfiguration (falls unterstützt)
2. Alternativ: Arduino-Code für ESP8266
3. MQTT-Payload-Format
4. Node-RED Flow für Datenverarbeitung
5. Grafana-Dashboard-Panel

Bitte liefere vollständige Konfiguration.
```

---

### Template 2: Neue Downsampling-Regel

```
Ich arbeite am Umweltbox-Projekt. Wir wollen eine neue Downsampling-Regel für [SENSOR-TYP] erstellen.

Anforderungen:
- Rohdaten: [INTERVALL, z.B. "1 Minute"]
- Aggregation 1: [ZEITRAUM, z.B. "nach 30 Tagen auf Stundenwerte"]
- Aggregation 2: [ZEITRAUM, z.B. "nach 1 Jahr auf Tageswerte"]
- Funktionen: [z.B. "mean, min, max"]

Bitte erstelle:
1. InfluxDB Task (Flux)
2. Retention Policy
3. Speicherplatz-Berechnung
```

---

### Template 3: Neues Grafana-Panel

```
Ich arbeite am Umweltbox-Projekt. Wir wollen ein neues Grafana-Panel erstellen.

Panel-Typ: [z.B. "Heatmap", "Bar Chart"]
Daten: [z.B. "CO2-Werte pro Klassenraum"]
Zeitraum: [z.B. "letzte 7 Tage"]

Anforderungen:
- Farb-Thresholds: [z.B. "<400 ppm = grün, >1000 ppm = rot"]
- Gruppierung: [z.B. "nach device_id"]
- Sortierung: [z.B. "nach Durchschnittswert"]

Bitte liefere:
1. Flux-Query
2. Panel-Konfiguration (JSON)
```

---

## 📚 Kontext-Dokumente für LLMs

Wenn du mit einem LLM arbeitest, füge folgende Dokumente als Kontext hinzu:

1. **01_Projektvision_und_Ziele.md** → Gesamtüberblick
2. **02_Architektur_Uebersicht.md** → Technischer Stack
3. **03_MQTT_Topic_Struktur.md** → MQTT-Konventionen
4. **04_InfluxDB_Schema.md** → Datenmodell
5. **05_Onboarding_Prozess.md** → Workflow für neue Tenants
6. **06_Speicherplanung_und_Downsampling.md** → Daten-Lifecycle
7. **07_Kartenvisualisierung.md** → Geo-Visualisierung
8. **08_Referenzprojekte.md** → Best Practices

**Beispiel-Prompt mit Kontext**:
```
Ich arbeite am Umweltbox-Projekt (siehe angehängte Dokumente).

[HIER SPEZIFISCHE AUFGABE EINFÜGEN]

Bitte berücksichtige:
- MQTT-Topic-Struktur aus Dokument 03
- InfluxDB-Schema aus Dokument 04
- Downsampling-Strategie aus Dokument 06
```

---

## 🔧 Tools für Prompt-Optimierung

### 1. ChatGPT / Claude / Gemini

**Empfehlung**: Nutze **Custom Instructions** (ChatGPT) oder **System Prompts** (Claude), um Projekt-Kontext dauerhaft zu speichern.

**Beispiel Custom Instruction**:
```
Ich arbeite an einem IoT-Projekt für Schulen (Umweltbox).
Stack: ESP8266, Tasmota, MQTT (Mosquitto), Node-RED, InfluxDB, Grafana.
Architektur: Multi-Tenant (isolierte Bereiche pro Schule).
Datenmodell: Tags (tenant_id, device_id, sensor_type), Fields (value).
Bitte generiere Code, der Best Practices folgt (TLS, ACL, Downsampling).
```

---

### 2. GitHub Copilot

**Empfehlung**: Lege Projekt-Dokumentation im Repository ab, damit Copilot Kontext hat.

**Beispiel-Dateistruktur**:
```
docs/
  01_Projektvision_und_Ziele.md
  02_Architektur_Uebersicht.md
  ...
src/
  mqtt/
    acl_generator.sh  # Copilot lernt aus existierendem Code
  node-red/
    flows.json
```

---

### 3. Cursor AI

**Empfehlung**: Nutze **@-Mentions**, um auf Dokumentation zu verweisen.

**Beispiel**:
```
@docs/03_MQTT_Topic_Struktur.md Erstelle einen Node-RED Flow, der MQTT-Daten validiert.
```

---

## 📝 Best Practices für LLM-Prompts

### ✅ DO

1. **Kontext geben**: "Ich arbeite am Umweltbox-Projekt..."
2. **Spezifisch sein**: "Erstelle eine Flux-Query für..." statt "Wie mache ich...?"
3. **Format vorgeben**: "Bitte liefere: 1. Code, 2. Erklärung, 3. Beispiel"
4. **Constraints nennen**: "Nutze nur Python 3.9+, keine externen Libraries außer..."
5. **Beispiele geben**: "Ähnlich wie in Dokument 05, aber für..."

### ❌ DON'T

1. **Vage Fragen**: "Wie funktioniert MQTT?" → Zu allgemein
2. **Ohne Kontext**: "Erstelle ein Dashboard" → Welche Daten? Welches Tool?
3. **Zu komplex**: "Erstelle die gesamte Infrastruktur" → In Teilaufgaben splitten
4. **Veraltete Infos**: "Nutze InfluxDB 1.x" → Wir nutzen 2.x

---

## 🚀 Nächste Schritte

1. **Teste die Prompts**: Probiere 2-3 Prompts aus und verfeinere sie
2. **Sammle Ergebnisse**: Speichere funktionierende Code-Snippets im Repository
3. **Erweitere die Sammlung**: Füge eigene Prompts hinzu (siehe Templates)
4. **Teile mit Community**: Veröffentliche Best Practices im Wiki

---

**Erstellt**: Januar 2026  
**Version**: 1.0  
**Autor**: Umweltbox-Projekt  
**Lizenz**: CC BY-SA 4.0 (frei verwendbar mit Namensnennung)
