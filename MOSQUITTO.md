# Mosquitto MQTT Broker - Dokumentation

**Version:** Eclipse Mosquitto 2.x  
**UID/GID:** 2003:2100  
**Ports:** 1883 (MQTT), 9001 (WebSocket)  
**Zugriff:** https://mintfv.peddy.net/mqtt (WebSocket über nginx)

---

## 📋 Quick Reference

<details>
<summary><b>Wichtige Befehle</b></summary>

```bash
# Service Management
docker compose up -d mosquitto          # Start Mosquitto
docker compose logs -f mosquitto        # Logs anzeigen
docker compose restart mosquitto        # Neustart
docker compose exec mosquitto sh        # Shell im Container

# MQTT Test mit Kommandozeilen-Tools
mosquitto_sub -h localhost -p 1883 -t "test/topic" -v
mosquitto_pub -h localhost -p 1883 -t "test/topic" -m "Hello MQTT"

# WebSocket Test (über nginx)
# Siehe JavaScript Beispiel unten
```

</details>

<details>
<summary><b>Client-Verbindung</b></summary>

**Native MQTT (Port 1883):**
```
Host: mintfv.peddy.net
Port: 1883
Protocol: MQTT
```

**WebSocket über HTTPS (Port 443):**
```
URL: wss://mintfv.peddy.net/mqtt
Protocol: WebSocket (MQTT over WebSocket)
```

</details>

<details>
<summary><b>Status & Monitoring</b></summary>

```bash
# Healthcheck manuell testen
docker compose exec mosquitto mosquitto_sub -t '$SYS/broker/version' -C 1

# Broker-Status abfragen
docker compose exec mosquitto mosquitto_sub -t '$SYS/#' -v

# Aktive Clients zählen
docker compose exec mosquitto mosquitto_sub -t '$SYS/broker/clients/active' -C 1

# Nachrichten-Statistik
docker compose exec mosquitto mosquitto_sub -t '$SYS/broker/messages/#' -v -C 5
```

</details>

---

## 🏗️ Architektur

```
┌─────────────────────────────────────────────────────────┐
│                    Internet (Port 443)                  │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS/WSS
                         ▼
┌────────────────────────────────────────────────────────┐
│  nginx (UID 2001)                                      │
│  - SSL Termination                                     │
│  - Rate Limiting: 30 req/s                             │
│  - Location: /mqtt → http://mosquitto:9001             │
└────────────────────────┬───────────────────────────────┘
                         │ HTTP WebSocket (intern)
                         ▼
┌────────────────────────────────────────────────────────┐
│  Mosquitto (UID 2003)                                  │
│  - Port 1883: Native MQTT                              │
│  - Port 9001: WebSocket MQTT                           │
│  - Persistence: /mosquitto/data/                       │
└────────────────────────────────────────────────────────┘
```

**Zugriffswege:**
1. **WebSocket über HTTPS:** `wss://mintfv.peddy.net/mqtt` → nginx → mosquitto:9001
2. **Native MQTT:** `mqtt://mintfv.peddy.net:1883` → mosquitto:1883 (nur intern/VPN)

---

## 📦 Installation & Konfiguration

### 1. Verzeichnisstruktur

```bash
mosquitto/
├── config/
│   └── mosquitto.conf              # Broker-Konfiguration
├── data/                           # Persistence-Daten (UID 2003:2100, 770)
│   └── .gitkeep
└── logs/                           # Logs (UID 2003:2100, 770)
    └── .gitkeep
```

### 2. mosquitto.conf Konfiguration

**Aktuelle Konfiguration:**

```conf
# ============================================================================
# MintFV Mosquitto MQTT Broker Configuration
# ============================================================================

# Persistence
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest stdout
log_type all

# ============================================================================
# Listener 1: Native MQTT (Port 1883)
# ============================================================================
listener 1883
protocol mqtt

# Anonymous access (ändern für Produktion!)
allow_anonymous true

# ============================================================================
# Listener 2: WebSocket (Port 9001)
# ============================================================================
listener 9001
protocol websockets

# Shared anonymous setting
# allow_anonymous true (see above)
```

**Wichtige Parameter:**
- `persistence true`: Nachrichten werden bei Neustart persistent gespeichert
- `allow_anonymous true`: **NUR für Tests!** In Produktion mit Authentifizierung arbeiten
- `log_dest stdout`: Logs über Docker Logs verfügbar
- Listener 1883: Native MQTT für direkte Verbindungen
- Listener 9001: WebSocket für Browser und nginx Reverse Proxy

### 3. docker-compose.yaml Konfiguration

```yaml
mosquitto:
  image: eclipse-mosquitto:latest
  container_name: mosquitto
  user: "2003:2100"
  restart: unless-stopped
  ports:
    - "1883:1883"     # Native MQTT
    - "9001:9001"     # WebSocket
  volumes:
    - ./mosquitto/config:/mosquitto/config:ro
    - ./mosquitto/data:/mosquitto/data:rw
    - ./mosquitto/logs:/mosquitto/logs:rw
  healthcheck:
    test: ["CMD", "mosquitto_sub", "-t", "$$SYS/broker/version", "-C", "1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 10s
  deploy:
    resources:
      limits:
        cpus: '0.25'
        memory: 64M
  networks:
    - mintfv-net
```

### 4. nginx WebSocket Reverse Proxy

**Rate Limits** (`nginx/conf/00-rate-limits.conf`):
```nginx
# Mosquitto MQTT WebSocket - 30 req/s mit Burst 50
limit_req_zone $binary_remote_addr zone=mqtt_ws:10m rate=30r/s;
```

**WebSocket Location** (`nginx/conf/ssl.conf`):
```nginx
# Mosquitto MQTT WebSocket reverse proxy
location /mqtt {
    limit_req zone=mqtt_ws burst=50 nodelay;
    limit_conn conn_limit 100;

    proxy_pass http://mosquitto:9001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Long timeouts for WebSocket connections
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_connect_timeout 60s;
    
    # WebSocket keep-alive
    proxy_buffering off;
}
```

**Wichtige WebSocket-Header:**
- `Upgrade: websocket`: Protokoll-Upgrade auf WebSocket
- `Connection: upgrade`: Keep-Alive für WebSocket
- `proxy_read_timeout 3600s`: 1 Stunde Timeout für lange Verbindungen
- `proxy_buffering off`: Kein Buffering für Echtzeit-Kommunikation

---

## 🔌 Client-Beispiele

### ESP32 / Arduino (PubSubClient)

```cpp
#include <WiFi.h>
#include <PubSubClient.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "mintfv.peddy.net";
const int mqtt_port = 1883;

WiFiClient espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  
  // WiFi verbinden
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi connected");
  
  // MQTT konfigurieren
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("]: ");
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    
    // Client ID generieren
    String clientId = "ESP32Client-";
    clientId += String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
      client.subscribe("sensors/+/data");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Beispiel: Temperatur publishen
  float temperature = 23.5;
  String payload = String(temperature);
  client.publish("sensors/esp32-01/temperature", payload.c_str());
  
  delay(10000); // 10 Sekunden Pause
}
```

### Node-RED MQTT Node

**MQTT In Node** (Subscribe):
```
Server: localhost:1883
Topic: sensors/+/temperature
QoS: 0
Output: auto-detect (JSON oder String)
```

**MQTT Out Node** (Publish):
```
Server: localhost:1883
Topic: commands/device-01/switch
QoS: 0
Retain: false
```

**Flow-Beispiel:**
```json
[
    {
        "id": "mqtt-in-1",
        "type": "mqtt in",
        "broker": "mqtt-broker-1",
        "topic": "sensors/+/temperature",
        "qos": "0",
        "datatype": "auto-detect",
        "name": "Subscribe Temperature"
    },
    {
        "id": "mqtt-broker-1",
        "type": "mqtt-broker",
        "name": "MintFV Mosquitto",
        "broker": "localhost",
        "port": "1883",
        "clientid": "",
        "autoConnect": true,
        "usetls": false,
        "protocolVersion": "4",
        "keepalive": "60"
    }
]
```

### Python (paho-mqtt)

```python
import paho.mqtt.client as mqtt
import time

# Callback bei erfolgreicher Verbindung
def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe("sensors/+/temperature")

# Callback bei eingehender Nachricht
def on_message(client, userdata, msg):
    print(f"{msg.topic}: {msg.payload.decode()}")

# MQTT Client erstellen
client = mqtt.Client(client_id="python-client-01")
client.on_connect = on_connect
client.on_message = on_message

# Verbinden
client.connect("mintfv.peddy.net", 1883, 60)

# Non-blocking loop starten
client.loop_start()

# Nachrichten publishen
try:
    while True:
        temperature = 23.5
        client.publish("sensors/python-01/temperature", f"{temperature}")
        print(f"Published: {temperature}")
        time.sleep(10)
except KeyboardInterrupt:
    print("Stopping...")
    client.loop_stop()
    client.disconnect()
```

**Installation:**
```bash
pip install paho-mqtt
```

### JavaScript / Node.js (MQTT.js)

**Native MQTT:**
```javascript
const mqtt = require('mqtt');

const client = mqtt.connect('mqtt://mintfv.peddy.net:1883', {
  clientId: 'nodejs-client-' + Math.random().toString(16).substr(2, 8),
  clean: true,
  connectTimeout: 4000,
  reconnectPeriod: 1000,
});

client.on('connect', () => {
  console.log('Connected to MQTT broker');
  client.subscribe('sensors/+/temperature', (err) => {
    if (!err) {
      console.log('Subscribed to sensors/+/temperature');
    }
  });
});

client.on('message', (topic, message) => {
  console.log(`${topic}: ${message.toString()}`);
});

// Nachricht publishen
setInterval(() => {
  const temperature = (Math.random() * 10 + 20).toFixed(2);
  client.publish('sensors/nodejs-01/temperature', temperature);
  console.log(`Published: ${temperature}`);
}, 10000);
```

**WebSocket (Browser):**
```html
<!DOCTYPE html>
<html>
<head>
  <title>MQTT WebSocket Test</title>
  <script src="https://unpkg.com/mqtt/dist/mqtt.min.js"></script>
</head>
<body>
  <h1>MQTT WebSocket Test</h1>
  <div id="status">Disconnected</div>
  <div id="messages"></div>

  <script>
    // WebSocket-Verbindung über nginx
    const client = mqtt.connect('wss://mintfv.peddy.net/mqtt', {
      clientId: 'browser-client-' + Math.random().toString(16).substr(2, 8),
      clean: true,
      reconnectPeriod: 1000,
    });

    client.on('connect', () => {
      document.getElementById('status').innerText = 'Connected';
      console.log('Connected to MQTT broker via WebSocket');
      
      // Subscribe
      client.subscribe('sensors/+/temperature', (err) => {
        if (!err) {
          console.log('Subscribed to sensors/+/temperature');
        }
      });
      
      // Publish Test-Nachricht
      client.publish('sensors/browser-01/temperature', '22.5');
    });

    client.on('message', (topic, message) => {
      const msg = `${topic}: ${message.toString()}`;
      console.log(msg);
      
      const div = document.createElement('div');
      div.innerText = msg;
      document.getElementById('messages').appendChild(div);
    });

    client.on('error', (err) => {
      console.error('Connection error:', err);
      document.getElementById('status').innerText = 'Error: ' + err.message;
    });

    client.on('offline', () => {
      document.getElementById('status').innerText = 'Offline';
    });
  </script>
</body>
</html>
```

**Installation (Node.js):**
```bash
npm install mqtt
```

---

## 🔐 Sicherheit & Authentifizierung

### Passwort-Datei erstellen

**1. Passwort-Datei generieren:**
```bash
docker compose exec mosquitto mosquitto_passwd -c /mosquitto/config/mosquitto.passwd admin
# Passwort eingeben wenn gefragt
```

**2. Weitere Benutzer hinzufügen:**
```bash
docker compose exec mosquitto mosquitto_passwd -b /mosquitto/config/mosquitto.passwd sensor01 secret123
docker compose exec mosquitto mosquitto_passwd -b /mosquitto/config/mosquitto.passwd nodered nodered_pwd
```

**3. mosquitto.conf anpassen:**
```conf
# Authentifizierung aktivieren
allow_anonymous false
password_file /mosquitto/config/mosquitto.passwd
```

**4. Broker neu laden:**
```bash
docker compose restart mosquitto
```

### ACL (Access Control Lists)

**1. ACL-Datei erstellen** (`mosquitto/config/mosquitto.acl`):
```acl
# Admin: Voller Zugriff
user admin
topic readwrite #

# Sensor01: Nur Publish in sensors/sensor01/#
user sensor01
topic write sensors/sensor01/#

# Node-RED: Read/Write in sensors/# und commands/#
user nodered
topic readwrite sensors/#
topic readwrite commands/#

# Anonyme Benutzer: Nur Read in public/#
pattern read public/#
```

**2. mosquitto.conf erweitern:**
```conf
allow_anonymous false
password_file /mosquitto/config/mosquitto.passwd
acl_file /mosquitto/config/mosquitto.acl
```

**3. Broker neu laden:**
```bash
docker compose restart mosquitto
```

### TLS/SSL für Native MQTT (Optional)

Wenn MQTT-Verbindungen nicht über nginx laufen sollen, kann Mosquitto direkt TLS verwenden:

```conf
# Listener mit TLS (Port 8883)
listener 8883
protocol mqtt
cafile /mosquitto/config/ca.crt
certfile /etc/letsencrypt/live/mintfv.peddy.net/fullchain.pem
keyfile /etc/letsencrypt/live/mintfv.peddy.net/privkey.pem
require_certificate false
tls_version tlsv1.2
```

**docker-compose.yaml erweitern:**
```yaml
volumes:
  - ./certbot/conf:/etc/letsencrypt:ro  # SSL-Zertifikate lesen
```

**Port 8883 freigeben:**
```yaml
ports:
  - "8883:8883"  # MQTT über TLS
```

---

## 📊 Monitoring & Debugging

### $SYS Topics

Mosquitto stellt System-Metriken über `$SYS/#` Topics bereit:

```bash
# Broker-Version
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/version' -C 1

# Uptime
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/uptime' -C 1

# Aktive Clients
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/clients/active' -C 1

# Nachrichten-Statistik
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/messages/received' -C 1
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/messages/sent' -C 1

# Alle $SYS Topics
mosquitto_sub -h localhost -p 1883 -t '$SYS/#' -v
```

### Docker Logs

```bash
# Echtzeit-Logs
docker compose logs -f mosquitto

# Letzte 100 Zeilen
docker compose logs --tail=100 mosquitto

# Logs seit bestimmter Zeit
docker compose logs --since 30m mosquitto
```

### Grafana Integration

**MQTT-Metriken in InfluxDB speichern** (via Node-RED):

1. Node-RED Flow: Subscribe `$SYS/#` → Parse → Write to InfluxDB
2. Grafana Dashboard: MQTT Broker Statistiken visualisieren

**Beispiel-Flow:**
```json
[
    {
        "id": "mqtt-sys-in",
        "type": "mqtt in",
        "broker": "mqtt-broker-1",
        "topic": "$SYS/broker/clients/active",
        "qos": "0",
        "name": "Active Clients"
    },
    {
        "id": "influx-out",
        "type": "influxdb out",
        "influxdb": "influxdb-config",
        "name": "Write to InfluxDB",
        "measurement": "mqtt_broker",
        "precision": "s",
        "retentionPolicy": "",
        "database": "mqtt_stats"
    }
]
```

---

## 💾 Backup & Restore

### Backup

**Persistence-Daten sichern:**
```bash
# Backup erstellen
sudo tar -czf mosquitto-backup-$(date +%Y%m%d).tar.gz mosquitto/data/

# Backup mit rsync
rsync -av mosquitto/data/ /backup/mosquitto-data/
```

**mosquitto.conf sichern:**
```bash
cp mosquitto/config/mosquitto.conf mosquitto/config/mosquitto.conf.backup
```

**Passwort- und ACL-Dateien:**
```bash
cp mosquitto/config/mosquitto.passwd mosquitto/config/mosquitto.passwd.backup
cp mosquitto/config/mosquitto.acl mosquitto/config/mosquitto.acl.backup
```

### Restore

**1. Service stoppen:**
```bash
docker compose stop mosquitto
```

**2. Daten wiederherstellen:**
```bash
sudo tar -xzf mosquitto-backup-20251227.tar.gz -C ./
```

**3. Permissions prüfen:**
```bash
sudo chown -R 2003:2100 mosquitto/data/
sudo chmod -R 770 mosquitto/data/
```

**4. Service starten:**
```bash
docker compose start mosquitto
```

---

## 🧪 Testing

### 1. Container-Status prüfen

```bash
docker compose ps mosquitto
```

Erwartete Ausgabe:
```
NAME        IMAGE                      STATUS        PORTS
mosquitto   eclipse-mosquitto:latest   Up (healthy)  1883/tcp, 9001/tcp
```

### 2. Healthcheck testen

```bash
docker compose exec mosquitto mosquitto_sub -t '$SYS/broker/version' -C 1
```

Erwartete Ausgabe:
```
mosquitto version 2.x.x
```

### 3. Native MQTT Test

**Terminal 1 (Subscribe):**
```bash
mosquitto_sub -h mintfv.peddy.net -p 1883 -t "test/topic" -v
```

**Terminal 2 (Publish):**
```bash
mosquitto_pub -h mintfv.peddy.net -p 1883 -t "test/topic" -m "Hello MQTT"
```

Terminal 1 sollte anzeigen:
```
test/topic Hello MQTT
```

### 4. WebSocket Test (über nginx)

Browser Console öffnen und JavaScript ausführen:
```javascript
const client = mqtt.connect('wss://mintfv.peddy.net/mqtt');
client.on('connect', () => {
  console.log('Connected!');
  client.subscribe('test/topic');
  client.publish('test/topic', 'Hello from Browser!');
});
client.on('message', (topic, message) => {
  console.log(`${topic}: ${message.toString()}`);
});
```

### 5. nginx Logs prüfen

```bash
docker compose logs -f nginx | grep mqtt
```

Erfolgreiche WebSocket-Verbindungen sollten sichtbar sein.

---

## 🔧 Troubleshooting

### Problem: Verbindung schlägt fehl

**Symptom:** Client kann sich nicht verbinden

**Lösungen:**
1. Container-Status prüfen: `docker compose ps mosquitto`
2. Logs anzeigen: `docker compose logs mosquitto`
3. Port-Bindungen prüfen: `docker compose port mosquitto 1883`
4. Firewall prüfen: `sudo ufw status`

### Problem: WebSocket 502 Bad Gateway

**Symptom:** Browser zeigt WebSocket-Fehler

**Lösungen:**
1. nginx Logs: `docker compose logs nginx | grep mqtt`
2. Mosquitto Logs: `docker compose logs mosquitto`
3. nginx neu laden: `docker compose restart nginx`
4. nginx Konfiguration testen: `docker compose exec nginx nginx -t`

### Problem: Permission Denied

**Symptom:** Container startet nicht, Fehler "Permission denied"

**Lösungen:**
```bash
# Permissions korrigieren
sudo chown -R 2003:2100 mosquitto/
sudo chmod -R 750 mosquitto/config
sudo chmod -R 770 mosquitto/data mosquitto/logs

# Container neu starten
docker compose restart mosquitto
```

### Problem: Authentication Failed

**Symptom:** Client-Verbindung wird mit "Authentication failed" abgelehnt

**Lösungen:**
1. Passwort-Datei prüfen: `docker compose exec mosquitto cat /mosquitto/config/mosquitto.passwd`
2. mosquitto.conf prüfen: `allow_anonymous` und `password_file` Einstellungen
3. Benutzer neu erstellen: `docker compose exec mosquitto mosquitto_passwd -b /mosquitto/config/mosquitto.passwd username password`
4. Broker neu laden: `docker compose restart mosquitto`

### Problem: Messages not retained

**Symptom:** Retained Messages gehen nach Neustart verloren

**Lösungen:**
1. Persistence aktiviert? `persistence true` in mosquitto.conf
2. Verzeichnis beschreibbar? `ls -la mosquitto/data/`
3. Logs prüfen: `docker compose logs mosquitto | grep persistence`

---

## 📚 Weiterführende Ressourcen

- **Offizielle Dokumentation:** https://mosquitto.org/documentation/
- **MQTT Spezifikation:** https://mqtt.org/mqtt-specification/
- **Eclipse Mosquitto Docker:** https://hub.docker.com/_/eclipse-mosquitto
- **MQTT.js (JavaScript):** https://github.com/mqttjs/MQTT.js
- **Paho MQTT (Python):** https://www.eclipse.org/paho/index.php?page=clients/python/index.php
- **PubSubClient (Arduino):** https://github.com/knolleary/pubsubclient

---

## 🔗 Siehe auch

- [README.md](README.md) - Hauptdokumentation und Service-Übersicht
- [NODERED.md](NODERED.md) - Node-RED MQTT-Integration
- [DOCKER.md](DOCKER.md) - Docker UID/GID Konventionen
- [BACKUP.md](BACKUP.md) - Backup-Strategie für alle Services
