# Umweltbox - MQTT Topic-Struktur

## 📡 Topic-Hierarchie

Die Topic-Struktur ist so designed, dass sie:
- **Generisch parsbar** ist (automatische Verarbeitung in Node-RED)
- **Multi-Tenancy** unterstützt (isolierte Bereiche pro Organisationseinheit)
- **Erweiterbar** ist (neue Kategorien/Sensoren ohne Änderung)
- **Lesbar** bleibt (Menschen können Topics verstehen)

## 🗂️ Standard-Topic-Format

```
umweltbox/{tenant-id}/{device-id}/{category}/{measurement}
```

### Komponenten erklärt

| Ebene | Beschreibung | Beispiele | Regex-Validierung |
|-------|--------------|-----------|-------------------|
| **umweltbox** | Namespace (fix) | `umweltbox` | `^umweltbox$` |
| **tenant-id** | Organisationseinheit | `de-hh-gs-altona`, `de-by-gym-max-planck` | `^[a-z]{2}-[a-z]{2}-[a-z0-9-]+$` |
| **device-id** | Eindeutige Geräte-ID | `esp01`, `raspi-42`, `sds011-a` | `^[a-z0-9-]+$` |
| **category** | Messkategorie | `environment`, `airquality`, `system`, `weather` | `^[a-z]+$` |
| **measurement** | Konkrete Messgröße | `temperature`, `humidity`, `pm25`, `cpu_temp` | `^[a-z0-9_]+$` |

## 📋 Tenant-ID Namenskonvention

### Format (Empfohlen)

```
{land}-{bundesland}-{schultyp}-{schulname}[-{einheit}]
```

**Beispiele**:
- `de-hh-gs-altona` (Grundschule Altona, Hamburg)
- `de-by-gym-max-planck` (Gymnasium Max Planck, Bayern)
- `de-nrw-rs-koeln-klasse10a` (Realschule Köln, Klasse 10a)
- `de-be-ag-klima` (Arbeitsgruppe Klima, Berlin)

### Komponenten

| Teil | Kürzel | Bedeutung | Beispiele |
|------|--------|-----------|-----------|
| **Land** | de | Deutschland (fix) | `de` |
| **Bundesland** | hh, by, nrw | ISO-ähnlich | `hh` (Hamburg), `by` (Bayern), `nrw` (Nordrhein-Westfalen) |
| **Schultyp** | gs, gym, rs, ag | Abkürzung | `gs` (Grundschule), `gym` (Gymnasium), `rs` (Realschule), `ag` (AG) |
| **Schulname** | altona, max-planck | Sprechend | Kleinbuchstaben, Bindestriche erlaubt |
| **Einheit** (optional) | klasse10a, ag-physik | Optional | Bei Bedarf für Sub-Tenants |

### Bundesländer-Kürzel

| Bundesland | Kürzel | Bundesland | Kürzel |
|------------|--------|------------|--------|
| Baden-Württemberg | bw | Niedersachsen | ni |
| Bayern | by | Nordrhein-Westfalen | nrw |
| Berlin | be | Rheinland-Pfalz | rp |
| Brandenburg | bb | Saarland | sl |
| Bremen | hb | Sachsen | sn |
| Hamburg | hh | Sachsen-Anhalt | st |
| Hessen | he | Schleswig-Holstein | sh |
| Mecklenburg-Vorpommern | mv | Thüringen | th |

## 📊 Kategorien & Messgrößen

### 1. Environment (Umweltdaten)

**Topic-Pattern**: `umweltbox/{tenant}/{device}/environment/{measurement}`

| Measurement | Beschreibung | Einheit | Beispiel-Payload |
|-------------|--------------|---------|------------------|
| `temperature` | Lufttemperatur | °C | `{"value": 23.5}` |
| `humidity` | Luftfeuchtigkeit | % | `{"value": 65.2}` |
| `pressure` | Luftdruck | hPa | `{"value": 1013.25}` |
| `co2` | CO2-Konzentration | ppm | `{"value": 850}` |
| `voc` | Flüchtige organische Verbindungen | ppb | `{"value": 120}` |

### 2. Airquality (Luftqualität)

**Topic-Pattern**: `umweltbox/{tenant}/{device}/airquality/{measurement}`

| Measurement | Beschreibung | Einheit | Sensor-Beispiel |
|-------------|--------------|---------|-----------------|
| `pm25` | Feinstaub PM2.5 | µg/m³ | SDS011, PMS5003 |
| `pm10` | Feinstaub PM10 | µg/m³ | SDS011, PMS5003 |
| `pm100` | Feinstaub PM10.0 | µg/m³ | PMS5003 |
| `aqi` | Air Quality Index | Index | Berechnet |

### 3. Weather (Wetterdaten)

**Topic-Pattern**: `umweltbox/{tenant}/{device}/weather/{measurement}`

| Measurement | Beschreibung | Einheit | Sensor-Beispiel |
|-------------|--------------|---------|-----------------|
| `precipitation` | Niederschlag | mm/h | Kipplöffel |
| `wind_speed` | Windgeschwindigkeit | m/s | Anemometer |
| `wind_direction` | Windrichtung | ° | Windfahne |
| `uv_index` | UV-Index | Index | UV-Sensor |

### 4. System (System-Metriken)

**Topic-Pattern**: `umweltbox/{tenant}/{device}/system/{measurement}`

| Measurement | Beschreibung | Einheit | Quelle |
|-------------|--------------|---------|--------|
| `cpu_temp` | CPU-Temperatur | °C | Raspberry Pi, Tasmota |
| `cpu_load` | CPU-Auslastung | % | Linux-System |
| `disk_usage` | Festplattennutzung | % | Linux-System |
| `uptime` | Betriebszeit | Sekunden | System |
| `rssi` | WLAN-Signalstärke | dBm | ESP8266/ESP32 |

## 💬 Payload-Format

### Standard-JSON-Format

```json
{
  "value": 23.5,
  "unit": "°C",
  "timestamp": 1704288000000
}
```

**Felder**:
- `value` (required): Der Messwert als Float
- `unit` (optional): Einheit als String
- `timestamp` (optional): Unix-Timestamp in Millisekunden (wird sonst von Node-RED ergänzt)

### Erweiterte Payloads (mit Geo-Daten)

Für mobile Geräte:
```json
{
  "value": 850,
  "unit": "ppm",
  "geo": {
    "lat": 53.5511,
    "lon": 9.9937,
    "alt": 12.0
  }
}
```

### Multi-Value Payloads

Wenn ein Gerät mehrere Werte gleichzeitig sendet (z.B. BME280):
```json
{
  "temperature": 23.5,
  "humidity": 65.2,
  "pressure": 1013.25
}
```

**Node-RED muss dieses in separate InfluxDB-Points aufteilen!**

## 🔍 Topic-Beispiele (Real)

### Tasmota ESP32 mit BME280 (Umweltsensor)

```
umweltbox/de-hh-gs-altona/esp-klassenraum-3b/environment/temperature
Payload: {"value": 22.8, "unit": "°C"}

umweltbox/de-hh-gs-altona/esp-klassenraum-3b/environment/humidity
Payload: {"value": 58.3, "unit": "%"}

umweltbox/de-hh-gs-altona/esp-klassenraum-3b/environment/pressure
Payload: {"value": 1015.2, "unit": "hPa"}
```

### Raspberry Pi mit SDS011 (Feinstaubsensor)

```
umweltbox/de-by-gym-max-planck/raspi-schulhof/airquality/pm25
Payload: {"value": 15.2, "unit": "µg/m³"}

umweltbox/de-by-gym-max-planck/raspi-schulhof/airquality/pm10
Payload: {"value": 23.7, "unit": "µg/m³"}
```

### Computer mit Telegraf (System-Monitoring)

```
umweltbox/de-nrw-rs-koeln/pc-informatik-01/system/cpu_temp
Payload: {"value": 59.3, "unit": "°C"}

umweltbox/de-nrw-rs-koeln/pc-informatik-01/system/cpu_load
Payload: {"value": 42.5, "unit": "%"}
```

### Mobile Messstation (mit GPS)

```
umweltbox/de-be-ag-klima/mobile-01/environment/temperature
Payload: {
  "value": 18.5,
  "unit": "°C",
  "geo": {"lat": 52.5200, "lon": 13.4050}
}
```

## 🚫 Was gehört NICHT ins Topic?

Folgende Informationen gehören **in den Payload**, nicht ins Topic:

- ❌ Messwerte
- ❌ Einheiten
- ❌ Zeitstempel
- ❌ Geo-Koordinaten (außer als Tag in InfluxDB)
- ❌ Status-Flags

**Warum?** Topics sollten stabil sein und nur Metadaten enthalten. Werte ändern sich ständig.

## 📝 ACL-Mapping

### Tenant-Admin (Lesezugriff auf alle Geräte des Tenants)

```
user de-hh-gs-altona-admin
topic readwrite umweltbox/de-hh-gs-altona/#
topic read $SYS/#
```

### Sensor (Schreibzugriff nur für eigene Topics)

```
user de-hh-gs-altona-esp01
topic write umweltbox/de-hh-gs-altona/esp01/#
topic read umweltbox/de-hh-gs-altona/commands/esp01/#
```

### Node-RED (Lesezugriff auf alles)

```
user nodered-global
topic read umweltbox/#
topic read $SYS/#
```

## 🔧 Validierung in Node-RED

Beispiel-Flow zum Validieren von Topics:

```javascript
// Topic-Validierung
const topicRegex = /^umweltbox\/([a-z]{2}-[a-z]{2}-[a-z0-9-]+)\/([a-z0-9-]+)\/([a-z]+)\/([a-z0-9_]+)$/;
const match = msg.topic.match(topicRegex);

if (!match) {
    node.error("Invalid topic format: " + msg.topic);
    return null;
}

msg.tenant_id = match[1];
msg.device_id = match[2];
msg.category = match[3];
msg.measurement = match[4];

return msg;
```

---

**Erstellt**: Januar 2026  
**Version**: 1.0
