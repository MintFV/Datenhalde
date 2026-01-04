# Umweltbox - Referenzprojekte

## 🌍 Übersicht

Diese Sammlung zeigt **erfolgreiche Citizen-Science- und IoT-Projekte**, die als Inspiration und technische Referenz für das Umweltbox-Projekt dienen. Alle Projekte sind Open Source oder Open Data.

## 📊 Vergleichstabelle

| Projekt | Fokus | Geräte | Daten | Technologie | Lizenz |
|---------|-------|--------|-------|-------------|--------|
| **Sensor.Community** | Luftqualität | 15.000+ | Open Data | ESP8266, InfluxDB | CC BY-SA 4.0 |
| **OpenAQ** | Luftqualität | 10.000+ | Open Data | API, PostgreSQL | CC BY 4.0 |
| **AirGradient** | Luftqualität | 5.000+ | Teilweise offen | ESP32, Cloud | Proprietär |
| **Purple Air** | Luftqualität | 20.000+ | Kommerziell | ESP32, Cloud | Proprietär |
| **Safecast** | Radioaktivität | 1.000+ | Open Data | Custom HW, API | CC0 |
| **Smart Citizen** | Multi-Sensor | 2.000+ | Open Data | ESP32, API | GPL v3 |
| **Luftdaten.info** | Luftqualität | 10.000+ | Open Data | ESP8266 | MIT |
| **OpenSenseMap** | Multi-Sensor | 8.000+ | Open Data | Arduino, API | LGPL |

## 1️⃣ Sensor.Community (ehem. Luftdaten.info)

### 📋 Projekt-Steckbrief

- **Website**: https://sensor.community
- **Start**: 2015 (Stuttgart, Deutschland)
- **Geräte**: ~15.000 aktive Sensoren weltweit
- **Fokus**: Feinstaub (PM2.5, PM10), Temperatur, Luftfeuchtigkeit
- **Zielgruppe**: Bürger*innen, Schulen, Kommunen

### 🛠️ Technischer Aufbau

**Hardware**:
- **MCU**: ESP8266 (NodeMCU v3)
- **Sensoren**: 
  - SDS011 (Feinstaub)
  - BME280 (Temperatur, Luftfeuchtigkeit, Luftdruck)
  - DHT22 (Alternative zu BME280)
- **Kosten**: ~30-40 € pro Gerät

**Software**:
- **Firmware**: Custom C++ (Arduino-Framework)
- **Protokoll**: HTTP POST (JSON) an API
- **Backend**: PHP, PostgreSQL, InfluxDB
- **Visualisierung**: Leaflet.js (Web-Karte)

**API-Endpunkt**:
```
https://api.sensor.community/v1/sensor/{sensor_id}/
```

**Beispiel-Response**:
```json
[
  {
    "id": 12345678,
    "timestamp": "2025-01-03 14:30:00",
    "location": {
      "latitude": "48.7758",
      "longitude": "9.1829"
    },
    "sensordatavalues": [
      {"value_type": "P1", "value": "15.23"},
      {"value_type": "P2", "value": "8.45"}
    ]
  }
]
```

### ✅ Lessons Learned (für Umweltbox)

| Aspekt | Sensor.Community | Umweltbox-Adaption |
|--------|------------------|-------------------|
| **Hardware** | Nur ESP8266 | Multi-Plattform (ESP, Raspi, PC) |
| **Protokoll** | HTTP POST | MQTT (effizienter) |
| **Datenbank** | PostgreSQL + InfluxDB | Nur InfluxDB (einfacher) |
| **Multi-Tenancy** | Keine | Ja (Schulen isoliert) |
| **Onboarding** | Manuell (Formular) | Automatisiert (Self-Service) |

**Übernahme**:
- ✅ Einfache Hardware-Bauanleitung
- ✅ Open Data Philosophie
- ✅ Community-getrieben

---

## 2️⃣ OpenSenseMap

### 📋 Projekt-Steckbrief

- **Website**: https://opensensemap.org
- **Start**: 2014 (Universität Münster, Deutschland)
- **Geräte**: ~8.000 aktive Senseboxen
- **Fokus**: Multi-Sensor (Umwelt, Klima, Lärm)
- **Zielgruppe**: Schulen, Forschung, Citizen Science

### 🛠️ Technischer Aufbau

**Hardware (senseBox)**:
- **MCU**: Arduino Uno + Ethernet Shield oder ESP32
- **Sensoren**: Modular (BME280, SDS011, UV, Lärm, etc.)
- **Kosten**: ~100-150 € (Komplettset)

**Software**:
- **Firmware**: Arduino C++ (Open Source)
- **Protokoll**: HTTP POST (JSON)
- **Backend**: Node.js, MongoDB
- **API**: RESTful (OpenAPI 3.0)
- **Visualisierung**: Leaflet.js + Chart.js

**API-Beispiel**:
```bash
# Alle Boxen in Deutschland
curl https://api.opensensemap.org/boxes?grouptag=Deutschland

# Daten einer Box
curl https://api.opensensemap.org/boxes/{boxId}/data/{sensorId}
```

### 🎓 Bildungskonzept

**Besonderheit**: Starker Fokus auf **Schulbildung**

- **Unterrichtsmaterialien**: Fertige Lerneinheiten (PDF, Videos)
- **Workshops**: Bundesweite Lehrerfortbildungen
- **Wettbewerbe**: "Hack your City" (Schüler-Projekte)
- **Zertifizierung**: "senseBox:edu" für Schulen

### ✅ Lessons Learned (für Umweltbox)

| Aspekt | OpenSenseMap | Umweltbox-Adaption |
|--------|--------------|-------------------|
| **Bildungsansatz** | Sehr stark | Übernehmen! |
| **Hardware-Kosten** | 100-150 € | 30-50 € (günstiger) |
| **Datenbank** | MongoDB | InfluxDB (besser für Zeitreihen) |
| **Onboarding** | Web-Formular | Automatisiert + Config-Download |
| **Multi-Tenancy** | Keine | Ja (wichtig für Schulen) |

**Übernahme**:
- ✅ Unterrichtsmaterialien-Konzept
- ✅ Modularer Sensor-Ansatz
- ✅ Community-Features (Forum, Projekte teilen)

---

## 3️⃣ AirGradient

### 📋 Projekt-Steckbrief

- **Website**: https://www.airgradient.com
- **Start**: 2020 (Thailand/USA)
- **Geräte**: ~5.000 aktive Geräte
- **Fokus**: CO2, PM2.5, Temperatur, Luftfeuchtigkeit
- **Zielgruppe**: Privathaushalte, Schulen, Büros

### 🛠️ Technischer Aufbau

**Hardware**:
- **MCU**: ESP32-C3
- **Sensoren**: 
  - PMS5003 (Feinstaub)
  - SenseAir S8 (CO2)
  - SHT40 (Temperatur, Luftfeuchtigkeit)
- **Display**: OLED (optional)
- **Kosten**: ~80-120 € (DIY-Kit)

**Software**:
- **Firmware**: Open Source (Arduino)
- **Protokoll**: MQTT + HTTP
- **Backend**: Proprietäre Cloud (kostenlos)
- **Alternative**: Lokale InfluxDB-Integration möglich
- **Visualisierung**: Web-Dashboard + Grafana

**MQTT-Topics**:
```
airgradient/{device_id}/pm25
airgradient/{device_id}/co2
airgradient/{device_id}/temperature
```

### 🌟 Besonderheiten

- **Kalibrierung**: Automatische Sensor-Kalibrierung
- **Firmware-Updates**: OTA (Over-The-Air)
- **Display**: Echtzeit-Anzeige am Gerät
- **API**: Öffentliche API für Daten-Export

### ✅ Lessons Learned (für Umweltbox)

| Aspekt | AirGradient | Umweltbox-Adaption |
|--------|-------------|-------------------|
| **Hardware-Qualität** | Sehr hoch | Anstreben (bessere Sensoren) |
| **CO2-Messung** | Ja (wichtig!) | Übernehmen |
| **Display** | Ja | Optional (Kosten) |
| **Cloud** | Proprietär | Open Source (InfluxDB) |
| **Kalibrierung** | Automatisch | Dokumentieren |

**Übernahme**:
- ✅ CO2-Sensor-Integration (wichtig für Schulen!)
- ✅ OTA-Update-Mechanismus
- ✅ Lokale Anzeige (motiviert Schüler*innen)

---

## 4️⃣ Safecast

### 📋 Projekt-Steckbrief

- **Website**: https://safecast.org
- **Start**: 2011 (nach Fukushima-Katastrophe)
- **Geräte**: ~1.000 Geigerzähler
- **Fokus**: Radioaktivität (Gamma-Strahlung)
- **Zielgruppe**: Bürger*innen in Japan, weltweit

### 🛠️ Technischer Aufbau

**Hardware (bGeigie Nano)**:
- **MCU**: Arduino Nano
- **Sensor**: LND 7317 Geiger-Müller-Zählrohr
- **GPS**: NEO-6M
- **Speicher**: SD-Karte (lokale Logs)
- **Kosten**: ~400-500 € (spezialisiert)

**Software**:
- **Firmware**: Open Source (C++)
- **Protokoll**: CSV-Upload via Web
- **Backend**: Ruby on Rails, PostgreSQL
- **API**: RESTful (JSON)
- **Visualisierung**: Leaflet.js (Heatmap)

**Daten-Format**:
```csv
timestamp,latitude,longitude,cpm,usv_h
2025-01-03T14:30:00Z,35.6762,139.6503,42,0.35
```

### 🌟 Besonderheiten

- **Mobile Messungen**: GPS-Tracking während Fahrten
- **Langzeitarchiv**: Daten seit 2011 verfügbar
- **Wissenschaftliche Nutzung**: Peer-reviewed Papers
- **Transparenz**: Alle Rohdaten downloadbar

### ✅ Lessons Learned (für Umweltbox)

| Aspekt | Safecast | Umweltbox-Adaption |
|--------|----------|-------------------|
| **Mobile Sensoren** | Ja (GPS-Tracking) | Übernehmen! |
| **Langzeitarchiv** | 10+ Jahre | Ja (tägliche Aggregate ewig) |
| **Daten-Download** | CSV/JSON | Ja (API + Export) |
| **Wissenschaft** | Viele Papers | Ziel für Umweltbox |

**Übernahme**:
- ✅ GPS-Tracking für mobile Messstationen
- ✅ CSV-Export für Offline-Analysen
- ✅ Langzeitarchivierung (wichtig für Forschung)

---

## 5️⃣ Smart Citizen

### 📋 Projekt-Steckbrief

- **Website**: https://smartcitizen.me
- **Start**: 2012 (Barcelona, Spanien)
- **Geräte**: ~2.000 Smart Citizen Kits
- **Fokus**: Multi-Sensor (Luft, Lärm, Licht)
- **Zielgruppe**: Urbane Communities, Aktivist*innen

### 🛠️ Technischer Aufbau

**Hardware (SCK 2.1)**:
- **MCU**: ESP32
- **Sensoren**: 
  - PMS5003 (Feinstaub)
  - BME680 (Temperatur, Luftfeuchtigkeit, VOC)
  - MEMS-Mikrofon (Lärm)
  - BH1730FVC (Licht)
- **Kosten**: ~150-200 €

**Software**:
- **Firmware**: Open Source (Arduino)
- **Protokoll**: HTTP POST (JSON)
- **Backend**: Python (Django), PostgreSQL
- **API**: RESTful (OpenAPI)
- **Visualisierung**: Custom Web-App (React)

**API-Beispiel**:
```bash
# Geräte-Infos
curl https://api.smartcitizen.me/v0/devices/{device_id}

# Letzte Messwerte
curl https://api.smartcitizen.me/v0/devices/{device_id}/readings
```

### 🌟 Besonderheiten

- **Community-Plattform**: Nutzer können Projekte teilen
- **Daten-Analyse-Tools**: Jupyter Notebooks
- **Kalibrierung**: Community-basierte Kalibrierungs-Algorithmen
- **Integration**: Sensor.Community, OpenAQ

### ✅ Lessons Learned (für Umweltbox)

| Aspekt | Smart Citizen | Umweltbox-Adaption |
|--------|---------------|-------------------|
| **Community-Features** | Sehr stark | Übernehmen (Forum, Projekte) |
| **Lärm-Messung** | Ja | Optional (Datenschutz!) |
| **Jupyter-Integration** | Ja | Für Schulen interessant |
| **Kalibrierung** | Community | Dokumentieren |

**Übernahme**:
- ✅ Community-Plattform (Projekte teilen)
- ✅ Jupyter-Notebooks für Schüler-Analysen
- ✅ Lärm-Sensor (optional, mit Datenschutz-Hinweis)

---

## 🔧 Technologie-Vergleich

### MQTT vs. HTTP POST

| Kriterium | MQTT | HTTP POST |
|-----------|------|-----------|
| **Overhead** | Sehr niedrig (~2 Bytes Header) | Hoch (~200 Bytes Header) |
| **Verbindung** | Persistent (Keep-Alive) | Pro Request neu |
| **QoS** | Ja (0, 1, 2) | Nein (nur TCP) |
| **Bidirektional** | Ja (Subscribe/Publish) | Nein (nur Request/Response) |
| **Firewall** | Port 8883 (manchmal blockiert) | Port 443 (immer offen) |
| **Komplexität** | Broker nötig | Einfacher (nur HTTP-Server) |

**Empfehlung für Umweltbox**: **MQTT** (effizienter, bidirektional für Commands)

---

### InfluxDB vs. PostgreSQL vs. MongoDB

| Kriterium | InfluxDB | PostgreSQL | MongoDB |
|-----------|----------|------------|---------|
| **Zeitreihen** | Nativ optimiert | Erweiterung (TimescaleDB) | Nicht optimal |
| **Downsampling** | Eingebaut (Tasks) | Manuell (Cron) | Manuell |
| **Query-Sprache** | Flux / InfluxQL | SQL | MongoDB Query Language |
| **Retention** | Automatisch | Manuell | Manuell |
| **Aggregationen** | Sehr schnell | Schnell | Mittel |
| **Schema** | Schema-on-write | Streng (Schema) | Schema-less |

**Empfehlung für Umweltbox**: **InfluxDB** (spezialisiert auf Zeitreihen)

---

## 📚 Weitere Inspirationen

### Internationale Projekte

| Projekt | Land | Fokus | URL |
|---------|------|-------|-----|
| **CityAir** | Belgien | Luftqualität | https://cityair.io |
| **HackAIR** | EU | Luftqualität | https://www.hackair.eu |
| **Array of Things** | USA | Smart City | https://arrayofthings.github.io |
| **LoRa Sensor Network** | Niederlande | Multi-Sensor | https://www.thethingsnetwork.org |

### Wissenschaftliche Studien

1. **"Citizen Science for Air Quality Monitoring"** (2020)
   - DOI: 10.1016/j.envint.2020.105768
   - Vergleich von Low-Cost-Sensoren mit Referenzgeräten

2. **"OpenSenseMap: A Citizen Science Platform"** (2018)
   - DOI: 10.3390/ijgi7030101
   - Technische Architektur und Datenqualität

3. **"Safecast: Successful Citizen Science"** (2016)
   - DOI: 10.1177/0162243916672433
   - Lessons Learned aus Fukushima-Projekt

---

## 🎯 Umweltbox-Alleinstellungsmerkmale

Was macht Umweltbox **einzigartig**?

| Feature | Umweltbox | Andere Projekte |
|---------|-----------|-----------------|
| **Multi-Tenancy** | ✅ Ja (Schulen isoliert) | ❌ Meist nicht |
| **Multi-Plattform** | ✅ ESP, Raspi, PC | ❌ Meist nur ESP |
| **System-Monitoring** | ✅ Ja (CPU, Disk) | ❌ Nur Umwelt |
| **Automatisches Onboarding** | ✅ Self-Service | ❌ Manuell |
| **Generischer MQTT-Parser** | ✅ Topic-basiert | ❌ Fest codiert |
| **Downsampling** | ✅ 4 Stufen (5m → Tag) | ❌ Meist nur Rohdaten |
| **Bildungsfokus** | ✅ Schulen primär | ⚖️ Teilweise |
| **Open Source** | ✅ Komplett | ⚖️ Teilweise |

---

## 📖 Literatur & Links

### Dokumentationen

- **Sensor.Community**: https://sensor.community/de/sensors/airrohr/
- **OpenSenseMap**: https://docs.opensensemap.org
- **AirGradient**: https://www.airgradient.com/documentation/
- **Safecast**: https://blog.safecast.org
- **Smart Citizen**: https://docs.smartcitizen.me

### Hardware-Shops

- **Sensor.Community Shop**: https://nettigo.eu/products/luftdaten-org-kit
- **senseBox Shop**: https://sensebox.kaufen
- **AirGradient Shop**: https://www.airgradient.com/shop/

### Communities

- **Sensor.Community Forum**: https://forum.sensor.community
- **OpenSenseMap Forum**: https://forum.opensensemap.org
- **AirGradient Forum**: https://forum.airgradient.com

---

**Erstellt**: Januar 2026  
**Version**: 1.0  
**Quellen**: Offizielle Projekt-Websites, wissenschaftliche Literatur, eigene Recherche
