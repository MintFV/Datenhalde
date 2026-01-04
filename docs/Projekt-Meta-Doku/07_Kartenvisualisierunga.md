# Umweltbox - Kartenvisualisierung

## 🗺️ Ziel der Kartenvisualisierung

Die räumliche Darstellung der Messdaten ist ein **Kernfeature** des Umweltbox-Projekts. Sie ermöglicht:
- **Geografische Muster** erkennen (z.B. urbane Wärmeinseln, Verkehrshotspots)
- **Vergleiche zwischen Standorten** (Stadt vs. Land, verschiedene Schulen)
- **Citizen Science** erlebbar machen (Schüler*innen sehen ihre Daten auf der Karte)
- **Öffentlichkeitsarbeit** (beeindruckende Visualisierungen für Präsentationen)

## 📊 Visualisierungs-Typen

### 1. Live-Karte (Aktuelle Messwerte)

**Zweck**: Zeigt die aktuellsten Messwerte aller Geräte auf einer Karte

**Features**:
- Farbcodierte Marker (z.B. grün = gute Luftqualität, rot = schlecht)
- Tooltips mit Detailwerten beim Hover
- Filter nach Sensor-Typ, Tenant, Zeitbereich
- Auto-Refresh (alle 5 Minuten)

**Technologie**: Grafana GeoMap Panel

**Beispiel-Use-Case**:
> "Wo ist die Luftqualität in Hamburg gerade am schlechtesten?"

---

### 2. Heatmap (Zeitliche Aggregation)

**Zweck**: Zeigt räumliche Verteilung über einen Zeitraum (z.B. Tagesmittelwerte)

**Features**:
- Interpolation zwischen Messpunkten (Kriging/IDW)
- Farbverläufe (z.B. blau = kalt, rot = warm)
- Zeitslider für Animation (z.B. Tagesverlauf)

**Technologie**: Grafana Heatmap + GeoMap oder externe Tools (Kepler.gl, Mapbox)

**Beispiel-Use-Case**:
> "Wie verteilt sich die Temperatur über den Tag in München?"

---

### 3. Trajektorien (Mobile Messstationen)

**Zweck**: Zeigt Bewegungspfade von mobilen Sensoren (z.B. Fahrrad-Messungen)

**Features**:
- Linien mit Farbcodierung nach Messwert
- Zeitstempel-Animation
- Geschwindigkeitsanzeige (optional)

**Technologie**: Grafana Geomap mit Polylines oder Deck.gl

**Beispiel-Use-Case**:
> "Wie ändert sich die Luftqualität auf dem Schulweg?"

---

### 4. Vergleichskarte (Multi-Tenant)

**Zweck**: Vergleicht Messwerte verschiedener Schulen/Regionen

**Features**:
- Side-by-Side-Ansicht oder Overlay
- Statistische Vergleiche (Mittelwerte, Extremwerte)
- Ranking (z.B. "Top 10 sauberste Standorte")

**Technologie**: Grafana Dashboard mit mehreren Panels

**Beispiel-Use-Case**:
> "Welche Schule hat die beste Luftqualität in NRW?"

## 🛠️ Technologie-Stack

### Primär: Grafana GeoMap Panel

**Vorteile**:
- ✅ Nativ in Grafana integriert
- ✅ Direkte InfluxDB-Anbindung
- ✅ Echtzeit-Updates
- ✅ Public Dashboards (ohne Login)
- ✅ Responsive (Mobile-fähig)

**Einschränkungen**:
- ❌ Begrenzte Kartenstile
- ❌ Keine komplexen Interpolationen
- ❌ Performance-Limit bei >10.000 Punkten

**Geeignet für**: Live-Karten, einfache Heatmaps

---

### Sekundär: Kepler.gl (für erweiterte Analysen)

**Vorteile**:
- ✅ Professionelle 3D-Visualisierungen
- ✅ Zeitslider-Animationen
- ✅ Hexagon-Binning (Aggregation)
- ✅ Export als HTML/PNG

**Einschränkungen**:
- ❌ Keine Echtzeit-Updates (CSV/GeoJSON-Export nötig)
- ❌ Komplexere Einrichtung

**Geeignet für**: Wissenschaftliche Präsentationen, Papers

---

### Tertiär: Custom Web-App (React + Mapbox/Leaflet)

**Vorteile**:
- ✅ Vollständige Kontrolle
- ✅ Custom-Features (z.B. Routing, POI-Integration)
- ✅ Branding

**Einschränkungen**:
- ❌ Hoher Entwicklungsaufwand
- ❌ Wartung nötig

**Geeignet für**: Langfristige Produktentwicklung

## 📍 Geo-Daten-Quellen

### Statische Standorte (Schulen)

**Quelle**: Device-Registry (PostgreSQL/SQLite)

**Schema**:
```sql
CREATE TABLE devices (
    device_id VARCHAR(50) PRIMARY KEY,
    tenant_id VARCHAR(100),
    name VARCHAR(200),
    location_type VARCHAR(50),  -- 'classroom', 'outdoor', 'mobile'
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    altitude DECIMAL(6, 2),
    address TEXT,
    created_at TIMESTAMP
);
```

**Beispiel-Daten**:
```sql
INSERT INTO devices VALUES
('esp-klassenraum-3b', 'de-hh-gs-altona', 'Klassenraum 3b', 'classroom', 
 53.5511, 9.9937, 12.0, 'Altonaer Straße 38, 20357 Hamburg', NOW());
```

**Verwendung in Node-RED**:
```javascript
// Geo-Lookup beim MQTT-Empfang
const deviceRegistry = global.get('deviceRegistry') || {};
const geo = deviceRegistry[msg.device_id];

if (geo) {
    msg.payload.latitude = geo.lat;
    msg.payload.longitude = geo.lon;
}
```

---

### Dynamische Standorte (Mobile Sensoren)

**Quelle**: GPS-Sensor im MQTT-Payload

**MQTT-Payload-Format**:
```json
{
  "value": 18.5,
  "unit": "°C",
  "geo": {
    "lat": 52.5201,
    "lon": 13.4051,
    "alt": 35.2,
    "accuracy": 5.0  // Meter (optional)
  }
}
```

**Node-RED-Verarbeitung**:
```javascript
// GPS-Daten extrahieren
if (msg.payload.geo) {
    msg.latitude = msg.payload.geo.lat;
    msg.longitude = msg.payload.geo.lon;
    msg.altitude = msg.payload.geo.alt || null;
} else {
    // Fallback: Statische Koordinaten aus Registry
    const geo = getStaticGeo(msg.device_id);
    msg.latitude = geo.lat;
    msg.longitude = geo.lon;
}
```

## 🎨 Grafana GeoMap Konfiguration

### Panel-Setup (JSON-Konfiguration)

```json
{
  "type": "geomap",
  "title": "Umweltbox Live-Karte",
  "datasource": "InfluxDB",
  "fieldConfig": {
    "defaults": {
      "custom": {
        "hideFrom": {
          "tooltip": false,
          "viz": false,
          "legend": false
        }
      },
      "mappings": [],
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {"value": null, "color": "green"},
          {"value": 25, "color": "yellow"},
          {"value": 50, "color": "orange"},
          {"value": 75, "color": "red"}
        ]
      },
      "color": {
        "mode": "thresholds"
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
    "controls": {
      "showZoom": true,
      "showAttribution": true,
      "mouseWheelZoom": true,
      "showDebug": false
    },
    "basemap": {
      "type": "osm-standard"
    },
    "layers": [
      {
        "type": "markers",
        "config": {
          "size": {
            "fixed": 8,
            "min": 2,
            "max": 15
          },
          "color": {
            "field": "value",
            "fixed": "dark-green"
          },
          "fillOpacity": 0.8,
          "shape": "circle"
        },
        "location": {
          "mode": "coords",
          "latitude": "latitude",
          "longitude": "longitude"
        },
        "tooltip": true
      }
    ]
  }
}
```

### Flux-Query für Live-Karte

```flux
from(bucket: "umweltbox")
  |> range(start: -15m)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r.sensor_type == "pm25")
  |> filter(fn: (r) => r._field == "value" or r._field == "latitude" or r._field == "longitude")
  |> last()  // Nur letzter Wert pro Gerät
  |> pivot(rowKey: ["device_id"], columnKey: ["_field"], valueColumn: "_value")
  |> filter(fn: (r) => exists r.latitude and exists r.longitude)
```

**Ergebnis-Schema**:
```
device_id         | value | latitude | longitude | _time
------------------|-------|----------|-----------|-------------------
esp-klassenraum-3b| 15.2  | 53.5511  | 9.9937    | 2025-01-03T14:30:00Z
raspi-schulhof    | 23.7  | 48.1351  | 11.5820   | 2025-01-03T14:28:00Z
```

### Farbcodierung nach Grenzwerten

**PM2.5 (Feinstaub) - WHO-Grenzwerte**:
```json
"thresholds": {
  "steps": [
    {"value": 0,   "color": "green"},   // Gut
    {"value": 15,  "color": "yellow"},  // Mäßig
    {"value": 25,  "color": "orange"},  // Ungesund für sensible Gruppen
    {"value": 50,  "color": "red"},     // Ungesund
    {"value": 75,  "color": "purple"}   // Sehr ungesund
  ]
}
```

**Temperatur**:
```json
"thresholds": {
  "steps": [
    {"value": -10, "color": "dark-blue"},
    {"value": 0,   "color": "light-blue"},
    {"value": 10,  "color": "green"},
    {"value": 20,  "color": "yellow"},
    {"value": 30,  "color": "orange"},
    {"value": 35,  "color": "red"}
  ]
}
```

## 🔥 Heatmap-Visualisierung

### Grafana Heatmap (Zeitbasiert)

**Zweck**: Zeigt Werte über Zeit und Raum (z.B. Tagesverlauf)

**Flux-Query**:
```flux
from(bucket: "umweltbox")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r.tenant_id == "de-hh-gs-altona")
  |> filter(fn: (r) => r.sensor_type == "temperature")
  |> filter(fn: (r) => r._field == "value")
  |> aggregateWindow(every: 1h, fn: mean)
  |> pivot(rowKey: ["_time"], columnKey: ["device_id"], valueColumn: "_value")
```

**Darstellung**: X-Achse = Zeit, Y-Achse = Geräte, Farbe = Temperatur

---

### Kepler.gl Heatmap (Räumlich)

**Workflow**:
1. **Daten exportieren** (InfluxDB → CSV/GeoJSON)
2. **Kepler.gl laden**: https://kepler.gl
3. **Datei hochladen**
4. **Layer konfigurieren**:
   - Layer-Typ: Heatmap
   - Radius: 1000m
   - Intensity: value
   - Color Range: Viridis

**Export-Query (Flux → CSV)**:
```flux
from(bucket: "umweltbox_daily")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r.sensor_type == "pm25")
  |> filter(fn: (r) => r._field == "value_mean")
  |> pivot(rowKey: ["_time", "device_id"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({
      time: r._time,
      device: r.device_id,
      lat: r.latitude,
      lon: r.longitude,
      pm25: r.value_mean
  }))
```

**CSV-Format**:
```csv
time,device,lat,lon,pm25
2025-01-01T00:00:00Z,esp01,53.5511,9.9937,12.5
2025-01-01T00:00:00Z,raspi01,48.1351,11.5820,18.3
```

## 🚴 Trajektorien (Mobile Sensoren)

### Grafana Geomap mit Polylines

**Flux-Query**:
```flux
from(bucket: "umweltbox")
  |> range(start: -2h)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r.device_id == "mobile-01")
  |> filter(fn: (r) => r.sensor_type == "temperature")
  |> filter(fn: (r) => r._field == "value" or r._field == "latitude" or r._field == "longitude")
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> sort(columns: ["_time"])
```

**Layer-Konfiguration**:
```json
{
  "type": "route",
  "config": {
    "style": {
      "color": {
        "field": "value",
        "fixed": "blue"
      },
      "size": 3,
      "opacity": 0.8
    }
  }
}
```

---

### Deck.gl (für komplexe Animationen)

**Technologie**: React + deck.gl TripsLayer

**Beispiel-Code**:
```javascript
import {TripsLayer} from '@deck.gl/geo-layers';

const layer = new TripsLayer({
  id: 'trips',
  data: trajectoryData,
  getPath: d => d.path,  // Array of [lon, lat]
  getTimestamps: d => d.timestamps,
  getColor: d => colorScale(d.value),
  opacity: 0.8,
  widthMinPixels: 2,
  rounded: true,
  trailLength: 180,
  currentTime: animationTime
});
```

## 📊 Dashboard-Beispiele

### Dashboard 1: "Bundesweite Übersicht"

**Panels**:
1. **GeoMap**: Alle aktiven Geräte mit letztem Messwert
2. **Stat Panel**: Anzahl aktiver Geräte
3. **Time Series**: Durchschnittswerte pro Bundesland
4. **Table**: Top 10 höchste/niedrigste Werte

**Filter-Variablen**:
- `$sensor_type` (Dropdown: temperature, pm25, humidity, ...)
- `$timerange` (Dropdown: Last 1h, Last 24h, Last 7d)

---

### Dashboard 2: "Schul-Detailansicht"

**Panels**:
1. **GeoMap**: Alle Geräte der Schule (zoomed in)
2. **Heatmap**: Tagesverlauf (X=Zeit, Y=Raum)
3. **Time Series**: Vergleich Innen vs. Außen
4. **Gauge**: Aktuelle Luftqualität (AQI)

**Filter-Variablen**:
- `$tenant` (fest gesetzt via URL-Parameter)

---

### Dashboard 3: "Mobile Messstation"

**Panels**:
1. **GeoMap**: Trajektorie der letzten 2 Stunden
2. **Time Series**: Messwerte über Fahrtzeit
3. **Stat Panel**: Zurückgelegte Strecke (km)
4. **Table**: Hotspots (höchste Werte)

## 🎓 Best Practices

### 1. Performance-Optimierung

**Problem**: Zu viele Datenpunkte → langsame Karte

**Lösungen**:
- **Clustering**: Gruppiere nahe Marker (Grafana Cluster-Layer)
- **Downsampling**: Nutze aggregierte Buckets für längere Zeiträume
- **Limit**: Zeige max. 1.000 Punkte gleichzeitig
- **Caching**: Statische Geo-Daten im Browser cachen

**Flux-Optimierung**:
```flux
from(bucket: "umweltbox")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> last()  // Nur letzter Wert pro Serie
  |> limit(n: 1000)  // Max. 1000 Punkte
```

---

### 2. Datenschutz & Anonymisierung

**Problem**: Genaue Standorte könnten Rückschlüsse auf Personen ermöglichen

**Lösungen**:
- **Geo-Fuzzing**: Koordinaten auf 100m runden (optional)
- **Aggregation**: Nur Durchschnittswerte pro Postleitzahl zeigen
- **Opt-Out**: Schulen können Standorte verbergen

**Beispiel (Geo-Fuzzing)**:
```javascript
// Runde auf ~100m Genauigkeit
const fuzzedLat = Math.round(lat * 1000) / 1000;  // 3 Dezimalstellen
const fuzzedLon = Math.round(lon * 1000) / 1000;
```

---

### 3. Barrierefreiheit

- **Farbblindheit**: Nutze Muster zusätzlich zu Farben
- **Kontrast**: Mindestens WCAG AA (4.5:1)
- **Tastaturnavigation**: Alle Funktionen per Tastatur bedienbar
- **Screen Reader**: Alt-Texte für Karten-Elemente

---

### 4. Mobile Optimierung

- **Responsive Design**: Karte passt sich Bildschirmgröße an
- **Touch-Gesten**: Pinch-to-Zoom, Swipe
- **Reduzierte Daten**: Weniger Marker auf kleinen Screens
- **Offline-Modus**: Cached Tiles für schlechte Verbindungen

## 🔗 Externe Ressourcen

### Kartendienste

| Dienst | Typ | Kosten | Lizenz |
|--------|-----|--------|--------|
| **OpenStreetMap** | Basiskarte | Kostenlos | ODbL |
| **Mapbox** | Basiskarte + Styles | 50k Views/Monat kostenlos | Proprietär |
| **CartoDB** | Basiskarte + Analytics | Kostenlos (Public) | BSD |

### Tools

- **Grafana GeoMap**: https://grafana.com/docs/grafana/latest/panels/visualizations/geomap/
- **Kepler.gl**: https://kepler.gl
- **Deck.gl**: https://deck.gl
- **Leaflet**: https://leafletjs.com
- **Mapbox GL JS**: https://docs.mapbox.com/mapbox-gl-js/

### Beispiel-Dashboards

- **AirGradient**: https://www.airgradient.com/open-airgradient/map/
- **Sensor.Community**: https://sensor.community/en/
- **OpenAQ**: https://openaq.org/#/map

## 📋 Checkliste: Karten-Setup

- [ ] Device-Registry mit Geo-Koordinaten befüllt
- [ ] InfluxDB-Schema enthält `latitude`/`longitude` Fields
- [ ] Grafana GeoMap Panel konfiguriert
- [ ] Basiskarte ausgewählt (OSM/Mapbox)
- [ ] Farbcodierung nach Grenzwerten eingerichtet
- [ ] Tooltips mit sinnvollen Informationen
- [ ] Filter-Variablen für Sensor-Typ/Zeitbereich
- [ ] Public Dashboard-Link erstellt
- [ ] Mobile-Ansicht getestet
- [ ] Performance-Test mit 1.000+ Punkten

---

**Erstellt**: Januar 2026  
**Version**: 1.0
