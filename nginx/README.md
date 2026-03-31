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
  ├─ /grafana/       → grafana:3000
  ├─ /nodered/       → nodered:1880
  ├─ /influxdb/      → influxdb:8181
  ├─ /selfservice/   → selfservice:5000
  └─ /mqtt           → mosquitto:9001 (WebSocket)

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
├── fullchain.pem  → ../archive/mintfv.peddy.net/fullchain1.pem
├── privkey.pem    → ../archive/mintfv.peddy.net/privkey1.pem
├── cert.pem       → ../archive/mintfv.peddy.net/cert1.pem
└── chain.pem      → ../archive/mintfv.peddy.net/chain1.pem
```

---

## ⚡ Rate Limiting & Security

### Rate Limit Zones (00-rate-limits.conf)

```nginx
# General: 10 req/s per IP
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# Grafana: 20 req/s
limit_req_zone $binary_remote_addr zone=grafana_general:10m rate=20r/s;

# InfluxDB: 10 req/s
limit_req_zone $binary_remote_addr zone=influxdb_general:10m rate=10r/s;

# Node-RED: 10 req/s
limit_req_zone $binary_remote_addr zone=nodered_general:10m rate=10r/s;

# MQTT WebSocket: 5 req/s
limit_req_zone $binary_remote_addr zone=mqtt_general:10m rate=5r/s;

# Selfservice: 5 req/s
limit_req_zone $binary_remote_addr zone=selfservice_general:10m rate=5r/s;

# Connection limit: 50 simultaneous connections per IP
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
```

### Security Maps (00-security-maps.conf)

**Blockierte Kategorien:**

- **Bad Bots:** Scanner (nikto, sqlmap, nmap), SEO-Crawler (AhrefsBot, MJ12bot), HTTP-Libraries (curl, wget, python-requests)
- **Scan URIs:** Admin-Panels (/phpmyadmin, /wp-admin), Source-Control (/.git), Config-Leaks (/.env, /configuration.php)
- **SQLi Patterns:** UNION SELECT, boolean-based injection, SQL comments
- **XSS Patterns:** Script-Injection, event-handler, iframe-injection
- **Exploits:** Log4Shell, path traversal, RCE-Versuche

**Map-Dateien:**

```
nginx/security_maps/
├── bad_bots.map          # User-Agent Blacklist
├── scan_uris.map         # Suspicious URI patterns
├── sensitive_files.map   # Config/Backup file leaks
├── sqli_patterns.map     # SQL Injection patterns
├── xss_patterns.map      # Cross-Site Scripting patterns
└── exploit_patterns.map  # Known exploit signatures
```

**Logging:** Blockierte Requests werden mit `reason=` geloggt (z.B. `reason=bad_bot`)

### Aktivierung in Location-Blöcken (02-ssl.conf)

```nginx
location /grafana/ {
    limit_req zone=grafana_general burst=100 nodelay;
    limit_conn conn_limit 50;
    # ...
}

location /influxdb/ {
    limit_req zone=influxdb_general burst=50 nodelay;
    limit_conn conn_limit 30;
    proxy_read_timeout 300s;   # 5 Min für lange Queries
    proxy_send_timeout 300s;
    # ...
}
```

---

## 🔧 Performance & Timeouts

### Client Timeouts (nginx.conf)

```nginx
client_body_timeout 120s;      # Request body read timeout
client_header_timeout 30s;     # Request header read timeout  
send_timeout 120s;             # Response send timeout
keepalive_timeout 120s;        # Keep-alive connection timeout
```

### Proxy Timeouts (für lange Queries)

```nginx
location /influxdb/ {
    proxy_read_timeout 300s;   # 5 Minuten für Analytics
    proxy_send_timeout 300s;
    proxy_connect_timeout 75s;
    # ...
}

location /grafana/ {
    proxy_read_timeout 300s;   # Dashboard rendering
    # ...
}
```

### Compression (gzip)

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript
           application/x-javascript application/xml+rss
           application/json application/javascript;
gzip_disable "msie6";
```

### Buffer Limits

```nginx
client_max_body_size 10M;           # Max upload size
client_body_buffer_size 128k;       # Body buffer
client_header_buffer_size 1k;       # Normal header buffer
large_client_header_buffers 2 4k;   # Max 2×4KB für große Headers/URIs
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
vi nginx/conf.d/02-ssl.conf
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
docker compose ps grafana nodered influxdb mosquitto selfservice

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
- **SSL:** Siehe [../certbot/SSL-SETUP.md](../certbot/SSL-SETUP.md)
- **Docs:** [nginx Documentation](https://nginx.org/en/docs/)
- **MQTT Stream:** [mosquitto/README.md](../mosquitto/README.md)
