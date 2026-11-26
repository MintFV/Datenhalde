# Umweltbox - InfluxDB Schema

## 🗄️ Datenbank-Design

InfluxDB 2.x/3.x nutzt ein **Schema-on-write** Design mit Measurements, Tags und Fields. Die Struktur ist optimiert für:
- Schnelle Zeitreihen-Abfragen
- Effiziente Aggregationen
- Flexible Filterung nach Metadaten

## 📊 Schema-Übersicht

### Measurement: `umweltbox`

Alle Sensordaten werden in einem einzigen Measurement gespeichert. Die Unterscheidung erfolgt über **Tags**.

```
measurement: umweltbox
├── tags (indexed)
│   ├── tenant_id       String  (e.g. "de-hh-gs-altona")
│   ├── device_id       String  (e.g. "esp01")
│   ├── category        String  (e.g. "environment", "airquality")
│   ├── sensor_type     String  (e.g. "temperature", "pm25")
│   └── location_type   String  (e.g. "classroom", "outdoor", "mobile")
│
├── fields (not indexed)
│   ├── value           Float   (der eigentliche Messwert)
│   ├── latitude        Float   (GPS-Koordinate, falls vorhanden)
│   ├── longitude       Float   (GPS-Koordinate, falls vorhanden)
│   ├── altitude        Float   (Höhe über NN, optional)
│   └── unit            String  (Einheit, z.B. "°C", "µg/m³")
│
└── timestamp           Timestamp (Unix Nanoseconds)
```

### Warum ein einziges Measurement?

✅ **Vorteile**:
- Vereinfachte Abfragen über mehrere Sensor-Typen
- Weniger Schema-Verwaltung
- Einfachere Multi-Tenant-Queries
- Konsistente Tag-Struktur

❌ **Alternative** (nicht empfohlen):
Separate Measurements pro Sensor-Typ würden Queries komplexer machen:
```
measurement: temperature
measurement: humidity
measurement: pm25
...
```

## 🏷️ Tag-Details

### `tenant_id` (String)

**Zweck**: Multi-Tenancy - Isolation der Daten pro Organisationseinheit

**Format**: `{land}-{bundesland}-{schultyp}-{schulname}[-{einheit}]`

**Beispiele**:
- `de-hh-gs-altona`
- `de-by-gym-max-planck`
- `de-nrw-rs-koeln-klasse10a`

**Cardinality**: ~1.000 (100 Schulen × 10 Sub-Units)

**Index**: Ja (primärer Filter)

---

### `device_id` (String)

**Zweck**: Eindeutige Identifikation des Geräts innerhalb eines Tenants

**Format**: Frei wählbar, empfohlen: `{geraetetyp}-{standort}-{nummer}`

**Beispiele**:
- `esp-klassenraum-3b`
- `raspi-schulhof`
- `pc-informatik-01`
- `mobile-messstation-07`

**Cardinality**: ~1.500 (pro Tenant bis zu 50 Geräte)

**Index**: Ja (häufiger Filter)

---

### `category` (String)

**Zweck**: Gruppierung der Messwerte nach Oberkategorie

**Erlaubte Werte**:
- `environment` (Temperatur, Feuchtigkeit, Druck)
- `airquality` (PM2.5, PM10, CO2, VOC)
- `weather` (Niederschlag, Wind, UV)
- `system` (CPU, RAM, Disk)

**Cardinality**: 4-6 (niedrig)

**Index**: Ja (häufiger Filter für Dashboard)

---

### `sensor_type` (String)

**Zweck**: Konkrete Messgröße (entspricht {measurement} aus MQTT-Topic)

**Beispiele**:
- `temperature`, `humidity`, `pressure`, `co2`
- `pm25`, `pm10`, `voc`
- `cpu_temp`, `cpu_load`, `disk_usage`

**Cardinality**: ~30 (mittelhoch)

**Index**: Ja (kritisch für Time-Series-Queries)

---

### `location_type` (String, optional)

**Zweck**: Art des Standorts (für Analysen)

**Beispiele**:
- `classroom` (Klassenraum)
- `outdoor` (Außenbereich)
- `lab` (Labor/Werkstatt)
- `mobile` (mobile Messstation)

**Cardinality**: 5-10 (niedrig)

**Index**: Ja (optional, aber nützlich)

## 📈 Field-Details

### `value` (Float)

**Zweck**: Der eigentliche Messwert

**Beispiele**:
- `23.5` (Temperatur in °C)
- `850.0` (CO2 in ppm)
- `15.2` (PM2.5 in µg/m³)

**Wichtig**: Immer als Float speichern, auch wenn Integer (für Aggregationen!)

---

### `latitude` / `longitude` (Float)

**Zweck**: GPS-Koordinaten des Geräts zum Messzeitpunkt

**Quellen**:
1. **Statisch**: Aus Device-Registry (einmalig bei Onboarding)
2. **Dynamisch**: Von mobilen Messstationen per MQTT

**Format**: Dezimalgrad (WGS84)
- `latitude`: -90.0 bis +90.0
- `longitude`: -180.0 bis +180.0

**Beispiel**:
```json
{
  "latitude": 53.5511,   // Hamburg
  "longitude": 9.9937
}
```

**Verwendung**: Grafana GeoMap Panel

---

### `altitude` (Float, optional)

**Zweck**: Höhe über Normalnull

**Einheit**: Meter

**Quelle**: GPS-Sensor oder manuell

---

### `unit` (String, optional)

**Zweck**: Einheit des Messwerts (für Display)

**Beispiele**:
- `°C`, `%`, `hPa`, `ppm`, `µg/m³`, `m/s`

**Hinweis**: Nicht zwingend nötig, da meist aus `sensor_type` ableitbar

## 🔍 Beispiel-Datenpunkte

### Temperatur-Messung

```
measurement: umweltbox
tags:
  tenant_id = "de-hh-gs-altona"
  device_id = "esp-klassenraum-3b"
  category = "environment"
  sensor_type = "temperature"
  location_type = "classroom"
fields:
  value = 22.8
  latitude = 53.5511
  longitude = 9.9937
  unit = "°C"
timestamp: 2025-01-03T14:30:00Z
```

### Feinstaub-Messung

```
measurement: umweltbox
tags:
  tenant_id = "de-by-gym-max-planck"
  device_id = "raspi-schulhof"
  category = "airquality"
  sensor_type = "pm25"
  location_type = "outdoor"
fields:
  value = 15.2
  latitude = 48.1351
  longitude = 11.5820
  unit = "µg/m³"
timestamp: 2025-01-03T14:30:00Z
```

### Mobile Messstation (Fahrrad-Tour)

```
measurement: umweltbox
tags:
  tenant_id = "de-be-ag-klima"
  device_id = "mobile-01"
  category = "environment"
  sensor_type = "temperature"
  location_type = "mobile"
fields:
  value = 18.5
  latitude = 52.5201   # <-- ändert sich mit jeder Messung!
  longitude = 13.4051
  altitude = 35.2
  unit = "°C"
timestamp: 2025-01-03T14:30:00Z
```

## 🗂️ Bucket-Struktur

> **Historisch – Zielbild:** Die Namen `umweltbox`, `umweltbox_15m`, `umweltbox_hourly` und `umweltbox_daily` sind v2-Bucket-Begriffe. Produktiv schreibt Node-RED in die InfluxDB-3-Datenbank `mintfv`, Measurement `sensors`. Siehe Abschnitt „Aktuelle Abfragen" und `10_Doku_Code_Abgleich_2026-11.md`.

### Bucket 1: `umweltbox` (Rohdaten)

**Retention**: 30 Tage (SZENARIO "MITTEL")

**Inhalt**: Alle 5-Minuten-Rohdaten

**Größe**: ~0.6 GB/Jahr (rollierend)

---

### Bucket 2: `umweltbox_15m` (15-Minuten-Aggregate)

**Retention**: 60 Tage

**Inhalt**: Mittelwerte, Min, Max über 15 Minuten

**Erzeugung**: Zielbild, aktuell nicht umgesetzt – siehe Abgleich-Dokument `10_Doku_Code_Abgleich_2026-11.md`

**Schema**:
```
measurement: umweltbox
tags: [gleich wie Rohdaten]
fields:
  value_mean = 22.5    # Mittelwert
  value_min = 21.8     # Minimum im Zeitfenster
  value_max = 23.2     # Maximum im Zeitfenster
  count = 3            # Anzahl Datenpunkte
timestamp: (aggregierter Zeitpunkt)
```

**Größe**: ~0.4 GB/Jahr (rollierend)

---

### Bucket 3: `umweltbox_hourly` (Stündliche Aggregate)

**Retention**: 275 Tage (~9 Monate)

**Inhalt**: Stündliche Mittelwerte

**Größe**: ~0.5 GB/Jahr (rollierend)

---

### Bucket 4: `umweltbox_daily` (Tägliche Aggregate)

**Retention**: ∞ (unbegrenzt)

**Inhalt**: Tägliche Mittelwerte, Min, Max

**Größe**: ~0.03 GB/Jahr (kumulativ)

## 🔧 Cardinality Management

**Was ist Cardinality?** Anzahl einzigartiger Tag-Kombinationen.

**Problem**: Hohe Cardinality = schlechte Performance!

### Cardinality-Berechnung (Worst Case)

```
tenant_id:       1.000  (100 Schulen × 10 Sub-Units)
device_id:       1.500  (durchschnittlich)
category:        4
sensor_type:     30
location_type:   5
────────────────────────
TOTAL:           ~900 Mio theoretisch
REAL:            ~50.000 (da nicht alle Kombinationen existieren)
```

### Best Practices

✅ **GUT**:
- Statische Werte als Tags (`tenant_id`, `device_id`)
- Kategorien mit wenigen Werten (<100)

❌ **SCHLECHT**:
- Messwerte als Tags (z.B. `temperature=22.5`)
- Zeitstempel als Tags
- UUIDs oder Session-IDs als Tags

## 🔍 Query-Beispiele (SQL)

Die folgenden Beispiele laufen gegen die produktive Datenbank `mintfv` und das Measurement `sensors` (InfluxDB 3 Core).

### Alle Temperaturen der letzten Stunde

```sql
SELECT time, tenant_id, device_id, sensor_type, value
FROM sensors
WHERE time > now() - interval '1 hour'
  AND sensor_type = 'temperature'
ORDER BY time DESC;
```

### PM2.5 für eine Schule (mit Geo-Daten)

```sql
SELECT time, value, latitude, longitude
FROM sensors
WHERE time > now() - interval '24 hours'
  AND tenant_id = 'de-hh-gs-altona'
  AND sensor_type = 'pm25'
ORDER BY time DESC;
```

### Vergleich mehrerer Schulen (Tagesmittelwerte)

Da keine Aggregate-Tabelle existiert, wird der Tagesmittelwert direkt berechnet:

```sql
SELECT date_trunc('day', time) AS day, tenant_id, avg(value) AS value_mean
FROM sensors
WHERE time > now() - interval '30 days'
  AND sensor_type = 'temperature'
GROUP BY day, tenant_id
ORDER BY day DESC;
```

---

## Aktuelle Abfragen (InfluxDB 3 Core, SQL)

Produktiv wird die Datenbank `mintfv` und das Measurement `sensors` verwendet (siehe `nodered/data/flows.json`). Beispiel über die CLI:

```sql
SELECT time, tenant_id, device_id, category, sensor_type, value
FROM sensors
WHERE time > now() - interval '1 hour'
  AND tenant_id = 'de-hh-mintfv-uwbox23'
ORDER BY time DESC
LIMIT 20;
```

```bash
influxdb3 query -d mintfv --token "$INFLUXDB_TOKEN" --format csv \
  "SELECT value FROM sensors WHERE time > now() - interval '10 minutes' AND tenant_id = 'de-hh-mintfv-uwbox23'"
```

---

**Erstellt**: Januar 2026  
**Version**: 1.0

Hinweis: Detaillierte Speicherberechnungen siehe 06_Speicherplanung_und_Downsampling.md (Szenario "MITTEL").
