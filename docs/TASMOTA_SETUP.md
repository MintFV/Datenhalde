# Tasmota MQTT Setup for MintFV

Konfigurationsanleitung für Tasmota-Geräte zur Integration in die MintFV-Plattform.

---

## 📋 MQTT Konfiguration

### Grundeinstellungen

```
Host: mintfv.peddy.net
Port: 8883 (MQTT over TLS)
MQTT TLS: ☑ aktiviert
User: tenant-a-sensor01
Password: sensor01

Topic: uwbox01 (Device-ID)
Full Topic: tenant/tenant-a/%topic%/
```

### Tasmota Console Commands

```
# Für bessere JSON-Ausgabe
SetOption4 1

# Topic-Struktur für Sensordaten
Topic uwbox01

# Full Topic für die tenant-a Struktur
FullTopic tenant/tenant-a/%topic%/
```

---

## 📡 MQTT Topics

Nach der Konfiguration publiziert Tasmota auf folgende Topics:

```
tenant/tenant-a/uwbox01/SENSOR    # JSON-Sensordaten (Temperatur, Luftfeuchtigkeit, etc.)
tenant/tenant-a/uwbox01/STATE     # Status-Informationen (Uptime, WiFi RSSI, etc.)
tenant/tenant-a/uwbox01/INFO1     # WiFi-Details
tenant/tenant-a/uwbox01/INFO2     # Firmware-Version
tenant/tenant-a/uwbox01/INFO3     # MQTT & Netzwerk-Details
```

---

## 🚀 Quick Setup (Backlog Command)

Für Ersteinrichtung eines Tasmota-Geräts:

```
Backlog Topic uwbox01; FriendlyName uwbox01; DeviceName uwbox01; Hostname uwbox01; SSID1 NWZ-Mint; Password1 XXXXXXXX; AP uwbox01; WifiConfig 4; SetOption55 1; SetOption56 1; WebPassword 0; SaveData
```

**Parameter-Erklärung:**
- `Topic uwbox01` - Device-ID für MQTT
- `FriendlyName/DeviceName/Hostname` - Identifikation
- `SSID1/Password1` - WiFi-Zugangsdaten
- `AP uwbox01` - Access Point Name bei Verbindungsproblemen
- `WifiConfig 4` - WiFi-Retry Strategie
- `SetOption55 1` - mDNS aktivieren
- `SetOption56 1` - WiFi Scan bei Reboot
- `WebPassword 0` - Web-Passwort deaktivieren (nur für Tests!)
- `SaveData` - Konfiguration speichern

⚠️ **Produktionsumgebung:**  
Für Produktion sollte `WebPassword` gesetzt werden!

---

## 🔐 Multi-Tenant Setup

Für unterschiedliche Tenants müssen nur User/Password und Full Topic angepasst werden:

### Tenant A (Beispiel oben)
```
User: tenant-a-sensor01
Password: sensor01
Full Topic: tenant/tenant-a/%topic%/
```

### Tenant B (Beispiel)
```
User: tenant-b-sensor01
Password: [siehe mosquitto/README.md]
Full Topic: tenant/tenant-b/%topic%/
```

---

## 📚 Weitere Informationen

- **MQTT ACLs:** [mosquitto/README.md](../mosquitto/README.md)
- **Node-RED Flow:** [nodered/README.md](../nodered/README.md)
- **Tasmota Docs:** <https://tasmota.github.io/docs/>
- **Datenblätter hier DHT22:** <https://www.elektronik-kompendium.de/sites/praxis/bauteil_dht22.htm>
