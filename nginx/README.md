# Nginx Reverse Proxy

HTTP/HTTPS Reverse Proxy & MQTT TLS Termination.

**Container:** mintfv-nginx (UID 2001:2100)  
**Image:** nginx:alpine  
**Ports:** 80 (HTTP→HTTPS), 443 (HTTPS), 8883 (MQTT over TLS)

---

## 🏗️ Architektur

### HTTP/HTTPS (Ports 80/443)
```
Client → nginx:443 (HTTPS) → Services
  ├─ /grafana/    → grafana:3000
  ├─ /nodered/    → nodered:1880
  ├─ /influxdb/   → influxdb:8181
  └─ /mqtt        → mosquitto:9001 (WebSocket)

Client → nginx:80 (HTTP) → Redirect 301 → HTTPS
```

### MQTT over TLS (Port 8883)
```
Client → nginx:8883 (TLS) → mosquitto:1883 (plain)
```

**Stream Logging Format:**
```
$remote_addr:$remote_port [$time_local] $protocol $status 
session=$session_time client_tx=$bytes_sent client_rx=$bytes_received 
upstream="$upstream_addr" upstream_tx=$upstream_bytes_sent 
upstream_rx=$upstream_bytes_received upstream_connect=$upstream_connect_time
```

---

## 📁 Konfigurationsstruktur

```
nginx/
├── nginx.conf              # Hauptkonfiguration
├── conf.d/                 # HTTP Server-Blöcke
│   ├── 00-filter-healthcheck.conf
│   ├── 00-rate-limits.conf
│   ├── 01-http.conf        # HTTP→HTTPS Redirect
│   └── 02-ssl.conf         # HTTPS + Reverse Proxies
├── stream.d/
│   └── mqtt.conf           # MQTT TLS Stream
└── html/
    ├── index.html
    └── favicon/
```

---

## 🔒 SSL/TLS Zertifikate

### Let's Encrypt (automatisch)
Zertifikate werden automatisch via certbot erneuert:
```bash
# Zertifikat-Status
docker compose exec certbot certbot certificates

# Manuell erneuern
docker compose exec certbot certbot renew
```

### Zertifikat-Pfade
```
/etc/letsencrypt/live/mintfv.peddy.net/
├── fullchain.pem  → ../archive/mintfv.peddy.net-0001/fullchain1.pem
├── privkey.pem    → ../archive/mintfv.peddy.net-0001/privkey1.pem
├── cert.pem       → ../archive/mintfv.peddy.net-0001/cert1.pem
└── chain.pem      → ../archive/mintfv.peddy.net-0001/chain1.pem
```

---

## ⚡ Rate Limiting

### Konfiguration (00-rate-limits.conf)
```nginx
# 30 req/s für InfluxDB Write
limit_req_zone $binary_remote_addr zone=influxdb_api:10m rate=30r/s;

# 100 req/s für Grafana
limit_req_zone $binary_remote_addr zone=grafana_api:10m rate=100r/s;

# 200 req/s für Node-RED
limit_req_zone $binary_remote_addr zone=nodered_api:10m rate=200r/s;
```

### Aktivierung in Location-Blöcken
```nginx
location /influxdb/ {
    limit_req zone=influxdb_api burst=10 nodelay;
    # ...
}
```

---

## 🧪 Testing & Debugging

### HTTP/HTTPS Test
```bash
# HTTPS funktioniert
curl -fsS https://mintfv.peddy.net/

# HTTP→HTTPS Redirect
curl -I http://mintfv.peddy.net/
# Expected: 301 Moved Permanently

# Grafana Proxy
curl -u admin:admin https://mintfv.peddy.net/grafana/api/health
```

### MQTT TLS Test
```bash
# Zertifikat prüfen
openssl s_client -connect mintfv.peddy.net:8883 -servername mintfv.peddy.net </dev/null 2>&1 | grep -E "(subject|issuer|Verify)"

# MQTT Publish über TLS
mosquitto_pub -h mintfv.peddy.net -p 8883 --capath /etc/ssl/certs \
  -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-a/sensor01/test" -m "test"
```

### MQTT Stream Logs
```bash
# Live-Logs für MQTT-Verbindungen
docker compose logs -f nginx | grep "TCP"

# Beispiel-Output:
# 188.192.29.233:65072 [29/Dec/2025:12:34:56 +0100] TCP 200 
# session=0.154 client_tx=4 client_rx=97 upstream="172.20.0.4:1883" 
# upstream_tx=97 upstream_rx=4 upstream_connect=0.000
```

---

## 🔧 Konfiguration ändern

### 1. Config bearbeiten
```bash
nano nginx/conf.d/02-ssl.conf
```

### 2. Syntax prüfen
```bash
docker compose exec nginx nginx -t
```

### 3. Neu laden (ohne Downtime)
```bash
docker compose exec nginx nginx -s reload
```

### 4. Kompletter Neustart
```bash
docker compose restart nginx
```

---

## ⚠️ Troubleshooting

### Problem: 502 Bad Gateway
```bash
# Backend-Service läuft?
docker compose ps grafana nodered influxdb mosquitto

# Nginx kann Backend erreichen?
docker compose exec nginx ping -c 1 grafana

# Nginx Logs
docker compose logs nginx | grep error
```

### Problem: SSL Zertifikat abgelaufen
```bash
# Zertifikat-Status prüfen
docker compose exec certbot certbot certificates

# Manuell erneuern
docker compose exec certbot certbot renew --force-renewal

# Nginx neu laden
docker compose exec nginx nginx -s reload
```

### Problem: MQTT TLS funktioniert nicht
```bash
# nginx Stream Logs
docker compose logs nginx | grep "8883\|TCP"

# Zertifikat prüfen
openssl s_client -connect mintfv.peddy.net:8883

# mosquitto erreichbar?
docker compose exec nginx nc -zv mosquitto 1883
```

---

## 📊 Monitoring

### nginx Status (optional)
```nginx
# In conf.d/02-ssl.conf hinzufügen:
location /nginx_status {
    stub_status;
    allow 127.0.0.1;
    deny all;
}
```

Abrufen:
```bash
docker compose exec nginx curl http://localhost:8080/nginx_status
```

### Logs exportieren (für Monitoring)
```bash
# Access Log
docker compose logs nginx | grep -v "GET /nginx_status"

# Error Log
docker compose logs nginx | grep error

# MQTT Stream Statistik
docker compose logs nginx | grep TCP | awk '{print $2, $5, $6}'
```

---

## 📚 Weitere Informationen

- **Config:** `nginx/nginx.conf`, `nginx/conf.d/`, `nginx/stream.d/`
- **Logs:** `docker compose logs nginx`
- **SSL:** Siehe [../SSL-SETUP.md](../SSL-SETUP.md)
- **Docs:** [nginx Documentation](https://nginx.org/en/docs/)
- **MQTT Stream:** [mosquitto/README.md](../mosquitto/README.md)
