# Tasmota MQTT Setup for Umweltbox (MintFV)

Konfigurationsanleitung für Tasmota-Geräte zur Integration in die Umweltbox-Plattform.

---

## 🏗️ MQTT Topic Architektur

Um die Sicherheit und Mandantenfähigkeit über MQTT ACLs (Access Control Lists) zu gewährleisten, nutzen wir eine hierarchische Struktur, die das Gerät an die erste Stelle nach dem Projekt-Präfix setzt.

**Standard:** `umweltbox/%topic%/%prefix%/`

Dies ermöglicht es, ACLs einfach auf Geräte-Ebene zu vergeben (z.B. `umweltbox/DE-HH-MINTFV-UWBOX01/#`).

---

## � Quick Setup (Backlog Commands)

### Ersteinrichtung (Neues Gerät)

Für die komplette Ersteinrichtung eines Tasmota-Geräts inkl. WiFi und Gerätenamen:

```text
Backlog Topic uwbox01; FriendlyName uwbox01; DeviceName uwbox01; Hostname uwbox01; SSID1 NWZ-Mint; Password1 XXXXXXXX; AP uwbox01; WifiConfig 4; SetOption55 1; SetOption56 1; WebPassword 0; SaveData
```

**Parameter-Erklärung:**
- `Topic`, `FriendlyName`, `DeviceName`, `Hostname`: Gerätename (z.B. `uwbox01`, später zu `de-hh-mintfv-uwbox01` erweitern)
- `SSID1`, `Password1`: WiFi-Zugangsdaten
- `AP`: Access Point Name (Fallback-WLAN)
- `WifiConfig 4`: WiFi-Konfigurationsmodus (4 = versuche SSID1, dann AP)
- `SetOption55 1`: mDNS aktivieren
- `SetOption56 1`: WiFi-Scan alle 44 Minuten
- `WebPassword 0`: Web-Interface ohne Passwort (für initiale Einrichtung)
- `SaveData`: Konfiguration speichern

### MQTT-Konfiguration (Bestehendes Gerät)

Für die Integration in die Umweltbox-Plattform (MQTT):

```text
Backlog Topic de-hh-mintfv-uwbox01; FullTopic umweltbox/%topic%/%prefix%/; SetOption4 1; SaveData
```

**Parameter-Erklärung:**
- `Topic`: Eindeutiger Gerätename (siehe Naming-Schema unten)
- `FullTopic`: MQTT-Topic-Struktur für ACL-Kompatibilität
- `SetOption4 1`: Bessere JSON-Ausgabe

---

## �📋 MQTT Konfiguration (Tasmota Web UI)

### Grundeinstellungen (Configuration -> Configure MQTT)

- **Host:** mintfv.peddy.net
- **Port:** 8883 (MQTT over TLS)
- **MQTT TLS:** Enabled
- **User:** de-hh-mintfv-uwbox01
- **Password:** uwbox01pw
- **Topic:** de-hh-mintfv-uwbox01
- **Full Topic:** umweltbox/%topic%/%prefix%/

---

## 💻 Tasmota Console Commands

Kopiere diese Befehle in die Tasmota-Konsole, um die korrekte Struktur sicherzustellen:

```bash
# Device Topic setzen
Topic de-hh-mintfv-uwbox01

# Full Topic Struktur anpassen (WICHTIG für ACL Kompatibilität)
FullTopic umweltbox/%topic%/%prefix%/

# Optionale Optimierungen
SetOption4 1   # Bessere JSON-Ausgabe
SetOption19 0  # Home Assistant Discovery aus (wenn nicht benötigt)
```

---

## 📡 Resultierende Topics

Mit dieser Konfiguration publiziert die Box auf:

- `umweltbox/de-hh-mintfv-uwbox01/tele/SENSOR`   # Sensordaten
- `umweltbox/de-hh-mintfv-uwbox01/tele/STATE`    # Status
- `umweltbox/de-hh-mintfv-uwbox01/cmnd/...`      # Empfang von Befehlen

---

## 🔐 Multi-Tenant / ACL Sicherheit

Die Mosquitto ACL (`mosquitto.acl`) muss für jedes Gerät wie folgt definiert sein:

```text
user de-hh-mintfv-uwbox01
topic write umweltbox/de-hh-mintfv-uwbox01/#
topic read umweltbox/de-hh-mintfv-uwbox01/cmnd/#
topic read $SYS/broker/version
```

*Hinweis: Tasmota nutzt standardmäßig `cmnd` als Prefix für Befehle. Falls in der ACL `commands` steht, muss dies entweder in der ACL auf `cmnd` geändert werden oder in Tasmota via `Prefix3 commands` überschrieben werden.*

---

## 📚 Weitere Informationen

- **MQTT ACLs:** [mosquitto/README.md](../mosquitto/README.md)
- **Node-RED Flow:** [nodered/README.md](../nodered/README.md)
- **Tasmota Docs:** <https://tasmota.github.io/docs/>
- **Datenblätter hier DHT22:** <https://www.elektronik-kompendium.de/sites/praxis/bauteil_dht22.htm>
