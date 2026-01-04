# Umweltbox - Kartenvisualisierung

## 🗺️ Ziel der Kartenvisualisierung

Die räumliche Darstellung der Messdaten ist ein **Kernfeature** des Umweltbox-Projekts. Sie ermöglicht:

- **Räumliche Muster erkennen**: Wo sind Hotspots? Wo sind Unterschiede?
- **Vergleiche zwischen Standorten**: Stadt vs. Land, Schulhof vs. Straße
- **Citizen Science**: Öffentlich zugängliche Karten für alle
- **Pädagogischer Wert**: Schüler*innen sehen ihre Daten im geografischen Kontext

## 📊 Visualisierungs-Typen

### 1. Live-Karte (Aktuelle Werte)

**Zweck**: Zeigt die **letzten Messwerte** aller Geräte auf einer Karte

**Features**:
- Farbcodierte Marker (z.B. grün = gut, rot = schlecht)
- Tooltips mit aktuellen Werten beim Hover
- Filter nach Sensor-Typ (Temperatur, PM2.5, etc.)
- Auto-Refresh alle 5 Minuten

**Technologie**: Grafana GeoMap Panel

---

### 2. Heatmap (Räumliche Verteilung)

**Zweck**: Zeigt **Intensitäten** als Heatmap (z.B. Feinstaubbelastung)

**Features**:
- Interpolation zwischen Messpunkten
- Zeitraffer-Animation (z.B. Tagesverlauf)
- Vergleich verschiedener Zeiträume

**Technologie**: Grafana Heatmap oder externe Tools (Leaflet.js)

---

### 3. Verlaufs-Karte (Zeitreihen auf Karte)

**Zweck**: Zeigt **Trends** pro Standort über Zeit

**Features**:
- Klick auf Marker → Time-Series-Chart
- Multi-Standort-Vergleich
- Historische Daten abrufbar

**Technologie**: Grafana GeoMap + Time Series Panel

---

### 4. Mobile Tracking (GPS-Routen)

**Zweck**: Zeigt **Bewegungsdaten** von mobilen Messstationen (z.B. Fahrrad-Touren)

**Features**:
- Routenverlauf mit Farbcodierung nach Messwert
- Playback-Funktion (Animation)
- Export als GPX/KML

**Technologie**: Grafana GeoMap mit Linien-Layer

## 🛠️ Technologie-Stack

### Grafana GeoMap Panel

**Vorteile**:
- ✅ Native Integration mit InfluxDB
- ✅ Keine zusätzliche Software nötig
- ✅ Public Dashboards möglich
- ✅ Responsive (funktioniert auf Handy)

**Nachteile**:
- ❌ Begrenzte Styling-Optionen
- ❌ Keine 3D-Visualisierungen
- ❌ Performance-Limits bei >10.000 Punkten

**Empfehlung**: **Perfekt für Umweltbox-Projekt** (1.500 Geräte = kein Problem)

---

### Alternative: Leaflet.js + Custom Frontend

**Vorteile**:
- ✅ Volle Kontrolle über Design
- ✅ Erweiterte Interaktivität
- ✅ 3D-Visualisierungen möglich (via Mapbox GL)

**Nachteile**:
- ❌ Mehr Entwicklungsaufwand
- ❌ Separate Hosting-Infrastruktur
- ❌ Wartungsaufwand

**Empfehlung**: Nur für spezielle Use Cases (z.B. wissenschaftliche Publikationen)

## 📍 Geo-Daten-Quellen

### Statische Standorte (Schulen/Gebäude)

**Quelle**: Device-Registry (Datenbank)

**Struktur**:
```sql
CREATE TABLE devices (
    device_id VARCHAR(100) PRIMARY KEY,
    tenant_id VARCHAR(100),
    name VARCHAR(255),
    location_name VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    altitude DECIMAL(6, 2),
    location_type VARCHAR(50),  -- classroom, outdoor, lab
    created_at TIMESTAMP
);
```

**Beispiel-Eintrag**:
```sql
INSERT INTO devices VALUES (
    'esp-klassenraum-3b',
    'de-hh-gs-altona',
    'ESP32 Klassenraum 3b',
    'Grundschule Altona, Hamburg',
    53.5511,
    9.9937,
    12.0,
    'classroom',
    NOW()
);
```

**Workflow**:
1. Beim Onboarding: Adresse eingeben
2. Backend: Geocoding via OpenStreetMap Nominatim API
3. Koordinaten in Datenbank speichern
4. Node-RED: Geo-Daten aus Registry holen und in InfluxDB schreiben

---

### Mobile Geräte (GPS-Tracker)

**Quelle**: MQTT-Payload (live)

**MQTT-Topic**:
```
umweltbox/{tenant}/{device}/environment/temperature
```

**Payload mit Geo-Daten**:
```json
{
  "value": 18.5,
  "unit": "°C",
  "geo": {
    "lat": 52.5201,
    "lon": 13.4051,
    "alt": 35.2,
    "accuracy": 5.0
  }
}
```

**Node-RED Verarbeitung**:
```javascript
// Geo-Daten aus Payload extrahieren
if (msg.payload.geo) {
    msg.latitude = msg.payload.geo.lat;
    msg.longitude = msg.payload.geo.lon;
    msg.altitude = msg.payload.geo.alt || null;
} else {
    // Fallback: Aus Device-Registry holen
    const device = getDeviceFromRegistry(msg.tenant_id, msg.device_id);
    msg.latitude = device.latitude;
    msg.longitude = device.longitude;
}
```

## 🎨 Grafana GeoMap Konfiguration

### Dashboard-Setup

**1. Neue Visualisierung erstellen**

- Panel-Typ: **Geomap**
- Datenquelle: **InfluxDB**

**2. Flux-Query (Aktuelle Werte)**

```flux
from(bucket: "umweltbox")
  |> range(start: -15m)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r.sensor_type == "temperature")
  |> filter(fn: (r) => r._field == "value" or r._field == "latitude" or r._field == "longitude")
  |> last()
  |> pivot(rowKey: ["device_id"], columnKey: ["_field"], valueColumn: "_value")
```

**Ergebnis**:
```
device_id          | value | latitude | longitude | _time
-------------------|-------|----------|-----------|-------------------
esp-klassenraum-3b | 22.8  | 53.5511  | 9.9937    | 2025-01-03T15:00:00Z
raspi-schulhof     | 18.2  | 53.5520  | 9.9950    | 2025-01-03T15:00:00Z
```

**3. GeoMap-Layer konfigurieren**

- **Layer-Typ**: Markers
- **Location**: Auto (latitude/longitude)
- **Size**: Fixed (10px) oder basierend auf Wert
- **Color**: Thresholds (siehe unten)

**4. Thresholds (Farbcodierung)**

Für Temperatur:
```
< 10°C   → Blau (#3498db)
10-20°C  → Grün (#27ae60)
20-25°C  → Gelb (#f39c12)
> 25°C   → Rot (#e74c3c)
```

Für PM2.5 (WHO-Grenzwerte):
```
0-10 µg/m³   → Grün (gut)
10-25 µg/m³  → Gelb (mäßig)
25-50 µg/m³  → Orange (ungesund für sensible Gruppen)
> 50 µg/m³   → Rot (ungesund)
```

**5. Tooltips konfigurieren**

```
Gerät: {{device_id}}
Wert: {{value}} {{unit}}
Standort: {{location_name}}
Letzte Messung: {{_time}}
```

### Beispiel-Dashboard-JSON (Auszug)

```json
{
  "type": "geomap",
  "title": "Umweltbox Live-Karte",
  "datasource": "InfluxDB",
  "targets": [
    {
      "query": "from(bucket: "umweltbox") |> range(start: -15m) |> filter(fn: (r) => r.sensor_type == "temperature") |> last()"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {"value": 0, "color": "blue"},
          {"value": 10, "color": "green"},
          {"value": 20, "color": "yellow"},
          {"value": 25, "color": "red"}
        ]
      }
    }
  },
  "options": {
    "view": {
      "id": "europe",
      "lat": 51.1657,
      "lon": 10.4515,
      "zoom": 6
    },
    "layers": [
      {
        "type": "markers",
        "config": {
          "size": {
            "fixed": 10
          },
          "color": {
            "field": "value",
            "fixed": "dark-green"
          }
        }
      }
    ]
  }
}
```

## 🌍 Basiskarten (Map Layers)

### OpenStreetMap (Standard)

**Vorteile**:
- ✅ Kostenlos
- ✅ Keine API-Keys nötig
- ✅ Gute Abdeckung in Deutschland

**URL**: `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`

---

### Mapbox (Optional, besseres Design)

**Vorteile**:
- ✅ Schönere Karten
- ✅ Satelliten-Layer verfügbar
- ✅ 3D-Gebäude

**Nachteile**:
- ❌ API-Key erforderlich
- ❌ 50.000 Requests/Monat kostenlos, dann kostenpflichtig

**URL**: `https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={token}`

---

### Empfehlung für Umweltbox

**OpenStreetMap** für öffentliche Dashboards (kostenlos, keine Limits)

## 📱 Responsive Design

### Desktop-Ansicht

- Karte: 70% der Breite
- Sidebar: 30% (Liste der Geräte, Filter)
- Zoom-Level: 6-8 (Deutschland-Übersicht)

### Mobile-Ansicht

- Karte: 100% der Breite
- Sidebar: Ausklappbar (Hamburger-Menü)
- Zoom-Level: Auto (basierend auf Geräte-Positionen)

### Grafana-Konfiguration

```json
{
  "panels": [
    {
      "type": "geomap",
      "gridPos": {
        "h": 20,
        "w": 24,
        "x": 0,
        "y": 0
      }
    }
  ]
}
```

## 🔍 Erweiterte Features

### 1. Cluster-Marker (bei vielen Geräten)

**Problem**: Bei 1.500 Geräten wird die Karte unübersichtlich

**Lösung**: Marker-Clustering (Geräte in der Nähe werden gruppiert)

**Implementierung**:
- Grafana: Aktuell keine native Unterstützung
- Workaround: Leaflet.js mit MarkerCluster-Plugin

**Beispiel** (Leaflet.js):
```javascript
var markers = L.markerClusterGroup();
data.forEach(function(device) {
    var marker = L.marker([device.lat, device.lon])
        .bindPopup(`<b>${device.name}</b><br>Temp: ${device.value}°C`);
    markers.addLayer(marker);
});
map.addLayer(markers);
```

---

### 2. Zeitraffer-Animation

**Zweck**: Zeigt Veränderungen über Zeit (z.B. Tagesverlauf)

**Implementierung**:
1. Flux-Query mit Zeitfenster (z.B. letzte 24h, alle 1h)
2. Grafana: Time-Series-Modus aktivieren
3. Playback-Button einblenden

**Flux-Query**:
```flux
from(bucket: "umweltbox_hourly")
  |> range(start: -24h)
  |> filter(fn: (r) => r.sensor_type == "pm25")
  |> filter(fn: (r) => r._field == "value_mean")
  |> aggregateWindow(every: 1h, fn: mean)
```

---

### 3. Vergleichs-Modus (Split-Screen)

**Zweck**: Zwei Zeiträume nebeneinander vergleichen

**Beispiel**:
- Links: Montag 08:00-10:00 Uhr
- Rechts: Freitag 08:00-10:00 Uhr

**Grafana-Setup**:
- Zwei GeoMap-Panels nebeneinander
- Unterschiedliche Time-Range-Overrides

---

### 4. Routen-Visualisierung (Mobile Geräte)

**Zweck**: GPS-Track mit Messwerten anzeigen

**Flux-Query**:
```flux
from(bucket: "umweltbox")
  |> range(start: -1h)
  |> filter(fn: (r) => r.device_id == "mobile-01")
  |> filter(fn: (r) => r.sensor_type == "temperature")
  |> filter(fn: (r) => r._field == "value" or r._field == "latitude" or r._field == "longitude")
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> sort(columns: ["_time"])
```

**GeoMap-Layer**:
- Layer-Typ: **Route** (Linien zwischen Punkten)
- Farbcodierung: Basierend auf Messwert

## 📊 Dashboard-Beispiele

### Dashboard 1: Bundesweite Übersicht

**Komponenten**:
- GeoMap (gesamtes Deutschland, Zoom 6)
- Filter: Sensor-Typ, Bundesland, Zeitraum
- Statistik-Panel: Anzahl aktiver Geräte, Durchschnittswerte

**URL**: `https://grafana.umweltbox.de/d/deutschland-overview`

---

### Dashboard 2: Schul-Dashboard (Tenant-spezifisch)

**Komponenten**:
- GeoMap (nur Geräte der Schule, Zoom 15)
- Time-Series: Verlauf der letzten 24h
- Tabelle: Aktuelle Werte aller Geräte

**URL**: `https://grafana.umweltbox.de/d/tenant?var-tenant=de-hh-gs-altona`

---

### Dashboard 3: Vergleichs-Dashboard

**Komponenten**:
- GeoMap: Alle Schulen in Hamburg
- Bar-Chart: Durchschnittswerte pro Schule
- Heatmap: Tagesverlauf (Stunden vs. Schulen)

**URL**: `https://grafana.umweltbox.de/d/city-comparison?var-city=hamburg`

## 🔐 Public Access

### Grafana Anonymous Access

**Konfiguration** (`grafana.ini`):
```ini
[auth.anonymous]
enabled = true
org_name = Umweltbox
org_role = Viewer

[security]
allow_embedding = true
```

**Effekt**: Jeder kann Dashboards ohne Login sehen (Read-Only)

### Embedding in Webseiten

**HTML-Code**:
```html
<iframe 
  src="https://grafana.umweltbox.de/d-solo/live-map/umweltbox-live?orgId=1&panelId=2" 
  width="100%" 
  height="600" 
  frameborder="0">
</iframe>
```

**Verwendung**:
- Schul-Webseiten
- Projekt-Homepage
- Wissenschaftliche Publikationen

## 🎓 Pädagogische Nutzung

### Unterrichtsideen

1. **Geografie**: Wo sind die Messstellen? Welche Regionen fehlen?
2. **Mathematik**: Durchschnitte berechnen, Korrelationen finden
3. **Physik**: Temperaturunterschiede Stadt/Land erklären
4. **Informatik**: Eigene Dashboards erstellen (Grafana-Workshop)

### Schüler-Projekte

- **Fahrrad-Tour**: Mobile Messstation durch die Stadt
- **Vergleichsstudie**: Schulhof vs. Straße vs. Park
- **Zeitreihenanalyse**: Wie ändert sich die Luftqualität über Wochen?

## 📚 Ressourcen

### Dokumentation

- Grafana GeoMap: https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/geomap/
- InfluxDB Flux Geo-Queries: https://docs.influxdata.com/flux/v0/stdlib/experimental/geo/
- Leaflet.js: https://leafletjs.com/

### Beispiel-Projekte

- **Sensor.Community**: https://maps.sensor.community/ (Feinstaub-Karte)
- **OpenSenseMap**: https://opensensemap.org/ (Citizen Science)
- **PurpleAir**: https://map.purpleair.com/ (Luftqualität)

---

**Erstellt**: Januar 2026  
**Version**: 1.0
