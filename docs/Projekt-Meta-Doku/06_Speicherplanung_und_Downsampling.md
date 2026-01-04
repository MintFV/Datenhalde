# Umweltbox - Speicherplanung & Downsampling

## 📊 Ausgangssituation

Das Umweltbox-Projekt sammelt kontinuierlich Zeitreihendaten von bis zu **1.500 Geräten** bundesweit. Die Herausforderung:
- **Langzeitarchivierung** (5-10 Jahre) für wissenschaftliche Auswertungen
- **Schnelle Abfragen** für aktuelle Dashboards
- **Kostenoptimierung** (Storage ist teuer)

Die Lösung: **Mehrstufiges Downsampling** mit InfluxDB.

## 🎯 Anforderungen

### Nutzungsszenarien

1. **Live-Monitoring** (letzte Stunden/Tage)
   - Auflösung: 5 Minuten (Rohdaten)
   - Anwendung: Aktuelle Dashboards, Alarmierung

2. **Kurzfristanalyse** (letzte Wochen)
   - Auflösung: 15 Minuten
   - Anwendung: Wochenvergleiche, Trendanalysen

3. **Mittelfristanalyse** (letztes Jahr)
   - Auflösung: 1 Stunde
   - Anwendung: Saisonale Muster, Monatsvergleiche

4. **Langzeitarchiv** (5-10 Jahre)
   - Auflösung: 1 Tag
   - Anwendung: Jahresvergleiche, Klimatrends, wissenschaftliche Papers

### Datenschutz & Retention

- **Open Data**: Alle Daten sind öffentlich (keine personenbezogenen Daten)
- **Ewige Archivierung**: Tägliche Aggregate werden nie gelöscht
- **Compliance**: DSGVO-konform (keine sensiblen Daten)

## 📈 Datenvolumen-Berechnung

### Annahmen

| Parameter | Wert | Einheit |
|-----------|------|---------|
| **Geräte gesamt** | 1.500 | Stück |
| **Umweltdaten-Geräte** | 1.000 | Stück (Sensoren) |
| **System-Monitoring-Geräte** | 500 | Stück (Computer) |
| **Messgrößen pro Umweltgerät** | 5 | (Temp, Humidity, Pressure, PM2.5, PM10) |
| **Messgrößen pro Computer** | 4 | (CPU Temp, CPU Load, Disk, RAM) |
| **Messintervall** | 5 | Minuten |
| **InfluxDB-Datenpunktgröße** | 150 | Bytes (geschätzt) |

### Rohdaten-Berechnung (5-Minuten-Intervall)

**Umweltdaten (1.000 Geräte):**
```
Datenpunkte/Tag = 1.000 Geräte × 5 Messgrößen × (1440 min / 5 min) = 1.440.000 Punkte/Tag
Speicher/Tag = 1.440.000 × 150 Bytes = 216 MB/Tag
Speicher/Jahr = 216 MB × 365 = 78,84 GB/Jahr
```

**Systemdaten (500 Computer):**
```
Datenpunkte/Tag = 500 Geräte × 4 Messgrößen × (1440 min / 5 min) = 576.000 Punkte/Tag
Speicher/Tag = 576.000 × 150 Bytes = 86,4 MB/Tag
Speicher/Jahr = 86,4 MB × 365 = 31,54 GB/Jahr
```

**Gesamt (Rohdaten):**
```
216 MB + 86,4 MB = 302,4 MB/Tag
78,84 GB + 31,54 GB = 110,38 GB/Jahr
```

### Downsampling-Stufen

#### Stufe 1: 15-Minuten-Aggregate

**Datenpunkte-Reduktion**: 5 Min → 15 Min = **Faktor 3**

```
Datenpunkte/Tag = 2.016.000 / 3 = 672.000 Punkte/Tag
Speicher/Tag = 672.000 × 200 Bytes = 134,4 MB/Tag  (größer wegen mean/min/max)
Speicher/Jahr = 134,4 MB × 365 = 49,06 GB/Jahr
```

#### Stufe 2: Stündliche Aggregate

**Datenpunkte-Reduktion**: 15 Min → 60 Min = **Faktor 4** (kumulativ: Faktor 12 vs. Rohdaten)

```
Datenpunkte/Tag = 672.000 / 4 = 168.000 Punkte/Tag
Speicher/Tag = 168.000 × 200 Bytes = 33,6 MB/Tag
Speicher/Jahr = 33,6 MB × 365 = 12,26 GB/Jahr
```

#### Stufe 3: Tägliche Aggregate

**Datenpunkte-Reduktion**: 1 Stunde → 24 Stunden = **Faktor 24** (kumulativ: Faktor 288 vs. Rohdaten)

```
Datenpunkte/Tag = 168.000 / 24 = 7.000 Punkte/Tag
Speicher/Tag = 7.000 × 200 Bytes = 1,4 MB/Tag
Speicher/Jahr = 1,4 MB × 365 = 511 MB/Jahr
```

## 💾 Retention Policies & Speicherszenarien

### Szenario 1: MINIMAL (Kostenoptimiert)

**Ziel**: Minimaler Storage bei akzeptabler Analyse-Tiefe

| Bucket | Auflösung | Retention | Speicher (rollierend) | Speicher (kumulativ über 10 Jahre) |
|--------|-----------|-----------|----------------------|-----------------------------------|
| `umweltbox` | 5 Minuten | 7 Tage | 2,1 GB | - |
| `umweltbox_15m` | 15 Minuten | 30 Tage | 4,0 GB | - |
| `umweltbox_hourly` | 1 Stunde | 90 Tage | 3,0 GB | - |
| `umweltbox_daily` | 1 Tag | ∞ | - | 5,1 GB |
| **TOTAL** | | | **9,1 GB** | **14,2 GB (nach 10 Jahren)** |

✅ **Vorteile**:
- Sehr geringer Storage-Bedarf
- Niedrige Kosten (~1-2 €/Monat)
- Ausreichend für meiste Analysen

❌ **Nachteile**:
- Rohdaten nur 7 Tage (Event-Analysen schwierig)
- 15-Minuten nur 1 Monat

---

### Szenario 2: MITTEL (Empfohlen) ✅

**Ziel**: Balance zwischen Kosten und Analysemöglichkeiten

| Bucket | Auflösung | Retention | Speicher (rollierend) | Speicher (kumulativ über 10 Jahre) |
|--------|-----------|-----------|----------------------|-----------------------------------|
| `umweltbox` | 5 Minuten | 30 Tage | 9,1 GB | - |
| `umweltbox_15m` | 15 Minuten | 60 Tage | 8,0 GB | - |
| `umweltbox_hourly` | 1 Stunde | 275 Tage (~9 Monate) | 9,2 GB | - |
| `umweltbox_daily` | 1 Tag | ∞ | - | 5,1 GB |
| **TOTAL** | | | **26,3 GB** | **31,4 GB (nach 10 Jahren)** |

✅ **Vorteile**:
- Rohdaten für kompletten Monat (gute Event-Analysen)
- 15-Minuten für 2 Monate (Wochenvergleiche)
- Stündlich fast ein Jahr (saisonale Muster)
- Langzeitarchiv (tägliche Werte ewig)

⚖️ **Kosten**: ~3-5 €/Monat

**Empfehlung**: **Dies ist der optimale Sweet-Spot für die meisten Use Cases!**

---

### Szenario 3: MAXIMAL (Forschungsumgebung)

**Ziel**: Maximale Datenqualität für wissenschaftliche Auswertungen

| Bucket | Auflösung | Retention | Speicher (rollierend) | Speicher (kumulativ über 10 Jahre) |
|--------|-----------|-----------|----------------------|-----------------------------------|
| `umweltbox` | 5 Minuten | 90 Tage | 27,2 GB | - |
| `umweltbox_15m` | 15 Minuten | 180 Tage | 24,2 GB | - |
| `umweltbox_hourly` | 1 Stunde | 2 Jahre | 24,5 GB | - |
| `umweltbox_daily` | 1 Tag | ∞ | - | 5,1 GB |
| **TOTAL** | | | **76,0 GB** | **81,1 GB (nach 10 Jahren)** |

✅ **Vorteile**:
- Rohdaten für 3 Monate (tiefgehende Analysen)
- 15-Minuten für halbes Jahr
- Stündlich für 2 Jahre
- Perfekt für wissenschaftliche Papers

❌ **Nachteile**:
- Höherer Storage-Bedarf
- Höhere Kosten (~7-10 €/Monat)

---

## 📊 Speicherverlauf über 10 Jahre (Visualisierung)

```
Storage (GB)
│
100 │                                        MAXIMAL (81 GB)
 90 │                                     ╱─────────────────
 80 │                                  ╱
 70 │                               ╱
 60 │                            ╱
 50 │                         ╱
 40 │               MITTEL (31 GB)
 30 │            ╱─────────────────────────────────────────
 20 │         ╱
 10 │ MINIMAL (14 GB)
  0 │╱──────────────────────────────────────────────────────
    └───────────────────────────────────────────────────────
    0    1    2    3    4    5    6    7    8    9    10 Jahre

Legende:
─────── Rollierender Speicher (konstant)
╱╱╱╱╱╱╱ Kumulativer Speicher (tägliche Aggregate)
```

**Interpretation**:
- Rollierender Speicher bleibt konstant (alte Daten werden gelöscht)
- Tägliche Aggregate wachsen linear (~511 MB/Jahr)
- Nach 10 Jahren nur ~5 GB zusätzlich (sehr effizient!)

## 🔄 InfluxDB Downsampling-Tasks (Flux)

### Task 1: 15-Minuten-Aggregation

```flux
option task = {
  name: "downsample_15m_umweltbox",
  every: 15m,
  offset: 5m  // Start 5 Minuten nach jeder vollen Stunde
}

from(bucket: "umweltbox")
  |> range(start: -20m, stop: -5m)  // Fenster: 20-5 Min in Vergangenheit
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r._field == "value")
  |> aggregateWindow(
      every: 15m,
      fn: mean,
      createEmpty: false
  )
  |> set(key: "_field", value: "value_mean")
  |> to(bucket: "umweltbox_15m", org: "umweltbox")

// Parallel: Min/Max in separate Tasks (oder Union)
```

### Task 2: Stündliche Aggregation

```flux
option task = {
  name: "downsample_hourly_umweltbox",
  every: 1h,
  offset: 10m
}

from(bucket: "umweltbox_15m")
  |> range(start: -75m, stop: -15m)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r._field == "value_mean")
  |> aggregateWindow(
      every: 1h,
      fn: mean,
      createEmpty: false
  )
  |> to(bucket: "umweltbox_hourly", org: "umweltbox")
```

### Task 3: Tägliche Aggregation

```flux
option task = {
  name: "downsample_daily_umweltbox",
  cron: "0 2 * * *"  // Jeden Tag um 02:00 Uhr UTC
}

from(bucket: "umweltbox_hourly")
  |> range(start: -2d, stop: -1d)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r._field == "value_mean")
  |> aggregateWindow(
      every: 1d,
      fn: mean,
      createEmpty: false,
      timeSrc: "_start"  // Tagesbeginn
  )
  |> to(bucket: "umweltbox_daily", org: "umweltbox")
```

### Task 4: Min/Max-Werte (optional)

Für erweiterte Statistiken:

```flux
// Parallel zu mean auch min/max berechnen
from(bucket: "umweltbox")
  |> range(start: -20m, stop: -5m)
  |> filter(fn: (r) => r._measurement == "umweltbox")
  |> filter(fn: (r) => r._field == "value")
  |> aggregateWindow(every: 15m, fn: min)
  |> set(key: "_field", value: "value_min")
  |> to(bucket: "umweltbox_15m")

// ... Wiederholen für max
```

## 🔧 Implementierung: Bucket-Setup

### 1. Buckets erstellen (via InfluxDB UI oder CLI)

```bash
# Rohdaten (30 Tage Retention)
influx bucket create   --name umweltbox   --org umweltbox   --retention 2592000s  # 30 Tage

# 15-Minuten (60 Tage)
influx bucket create   --name umweltbox_15m   --org umweltbox   --retention 5184000s  # 60 Tage

# Stündlich (275 Tage)
influx bucket create   --name umweltbox_hourly   --org umweltbox   --retention 23760000s  # 275 Tage

# Täglich (unbegrenzt)
influx bucket create   --name umweltbox_daily   --org umweltbox   --retention 0  # Keine Retention
```

### 2. Tasks anlegen (via InfluxDB UI)

1. **Navigation**: Settings → Tasks → Create Task
2. **Flux-Code einfügen** (siehe oben)
3. **Schedule konfigurieren** (every/cron)
4. **Speichern & Aktivieren**

### 3. Monitoring einrichten

**Task-Erfolg überwachen**:
```flux
from(bucket: "_tasks")
  |> range(start: -1d)
  |> filter(fn: (r) => r._measurement == "runs")
  |> filter(fn: (r) => r.status != "success")
```

**Speicher-Statistiken**:
```bash
influx bucket list --org umweltbox --json | jq '.[] | {name, retentionPeriod}'
```

## 📉 Speicherkosten-Vergleich

### Cloud-Storage (AWS S3 / DigitalOcean Spaces)

| Szenario | Speicher nach 1 Jahr | Speicher nach 10 Jahren | Kosten/Monat (AWS S3) | Kosten/Jahr |
|----------|---------------------|------------------------|----------------------|------------|
| **MINIMAL** | 9,1 GB | 14,2 GB | ~$0.32 | ~$3.84 |
| **MITTEL** | 26,3 GB | 31,4 GB | ~$0.72 | ~$8.64 |
| **MAXIMAL** | 76,0 GB | 81,1 GB | ~$1.86 | ~$22.32 |

**Preisannahme**: $0.023/GB/Monat (AWS S3 Standard, us-east-1)

### On-Premise (dedizierter Server)

| Szenario | Storage | Hardware | Kosten (einmalig) | Kosten/Jahr (Strom) |
|----------|---------|----------|-------------------|---------------------|
| **MITTEL** | 100 GB SSD | Intel NUC (512 GB SSD, 16 GB RAM) | ~€400 | ~€50 |
| **MAXIMAL** | 250 GB SSD | Gleiche Hardware | ~€400 | ~€50 |

**ROI**: On-Premise lohnt sich ab ~3-5 Jahren

## 🎓 Best Practices

### 1. Aggregations-Funktionen wählen

| Use Case | Funktion | Beispiel |
|----------|----------|----------|
| Durchschnitt | `mean` | Temperatur-Tagesmittel |
| Maximum | `max` | Hitzerekorde |
| Minimum | `min` | Kälteste Nacht |
| Summe | `sum` | Niederschlagsmenge |
| Anzahl | `count` | Anzahl Messwerte |

### 2. Task-Scheduling optimieren

- **15-Minuten-Task**: Alle 15 Min (z.B. :00, :15, :30, :45)
- **Stündlich**: Einmal pro Stunde (z.B. :10 nach der vollen Stunde)
- **Täglich**: Nachts um 02:00 UTC (niedrige Last)

### 3. Backups

**Tägliche Aggregate** unbedingt sichern (sind irreversibel!):

```bash
# Backup (InfluxDB Line Protocol)
influx backup /backup/umweltbox_daily   --bucket umweltbox_daily   --org umweltbox

# Restore
influx restore /backup/umweltbox_daily   --bucket umweltbox_daily_restored   --org umweltbox
```

### 4. Monitoring & Alerting

- **Disk-Usage**: Alarm bei >80% voll
- **Task-Failures**: E-Mail bei fehlgeschlagenen Downsampling-Tasks
- **Data-Gaps**: Warnung bei >1h ohne Daten

## 📊 Vergleichstabelle: Alle Szenarien

| Kriterium | MINIMAL | MITTEL ✅ | MAXIMAL |
|-----------|---------|----------|---------|
| **Rohdaten-Retention** | 7 Tage | 30 Tage | 90 Tage |
| **15-Min-Retention** | 30 Tage | 60 Tage | 180 Tage |
| **Stündlich-Retention** | 90 Tage | 275 Tage | 2 Jahre |
| **Storage (rollierend)** | 9,1 GB | 26,3 GB | 76,0 GB |
| **Storage nach 10 Jahren** | 14,2 GB | 31,4 GB | 81,1 GB |
| **Kosten (AWS S3/Monat)** | $0.32 | $0.72 | $1.86 |
| **Geeignet für** | Basisdashboards | 95% aller Analysen | Wissenschaftliche Projekte |

## 🚀 Empfehlung

**Für Umweltbox-Projekt: Szenario "MITTEL"**

**Begründung**:
- ✅ Rohdaten 30 Tage = gut für Event-Analysen (z.B. "Straßensperrung letzte Woche")
- ✅ 15-Min für 2 Monate = Wochenvergleiche möglich
- ✅ Stündlich ~9 Monate = saisonale Muster erkennbar
- ✅ Tägliche Werte ewig = Langzeittrends für wissenschaftliche Papers
- ✅ Kosten: ~$8-10/Jahr = **vernachlässigbar** für ein Bildungsprojekt
- ✅ Storage: 31 GB nach 10 Jahren = **jeder Raspberry Pi kann das!**

**Migration später möglich**: Von MITTEL zu MAXIMAL jederzeit aufrüstbar.

---

**Erstellt**: Januar 2026  
**Version**: 1.0  
**Basis-Analyse**: Detaillierte Berechnungen vom 2025-01-03
