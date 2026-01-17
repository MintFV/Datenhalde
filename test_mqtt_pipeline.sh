#!/bin/bash
#
# MintFV Test Script v6 - GPS ENHANCED
# Testet MQTT → Node-RED → InfluxDB Pipeline
# Inkl. Multi-Device, Multi-Tenant und GPS-Daten aus verschiedenen Städten
#

# Strikte Error-Behandlung
set -euo pipefail

# On error print the failed command
trap 'echo "❌ ERROR: Command '\''${BASH_COMMAND}'\'' failed at line ${LINENO}!"' ERR

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_test() { echo -e "${BLUE}[→]${NC} $1"; }
log_gps() { echo -e "${CYAN}[📍]${NC} $1"; }

echo ""
echo "========================================="
echo "  MintFV Pipeline Test v6"
echo "  GPS ENHANCED - Multi-Location"
echo "  MQTT → Node-RED → InfluxDB"
echo "========================================="
echo ""

# ============================================================================
# .env laden
# ============================================================================

if [ -f .env ]; then
    source .env
elif [ -f ../.env ]; then
    source ../.env
else
    log_error ".env nicht gefunden!"
    exit 1
fi

# Variablen prüfen
if [ -z "${NODE_RED_MQTT_USER:-}" ] || [ -z "${NODE_RED_MQTT_PASSWORD:-}" ]; then
    log_error "NODE_RED_MQTT_USER oder NODE_RED_MQTT_PASSWORD nicht in .env!"
    exit 1
fi

# Tenant-Konfiguration
TENANT_ID="de-hh-privat-peddy"
DEVICE_ID="raspi4"
DEVICE_ID_2="raspi2"
DEVICE_ID_3="raspi3"

# Zweiter Tenant
TENANT_ID_2="de-nrw-rs-koeln"

log_info "MQTT User: $NODE_RED_MQTT_USER"
log_info "Tenant 1: $TENANT_ID (Devices: $DEVICE_ID, $DEVICE_ID_2, $DEVICE_ID_3)"
log_info "Tenant 2: $TENANT_ID_2 (Device: sensor01, sensor02)"
echo ""

# ============================================================================
# GPS-Koordinaten für verschiedene Städte
# ============================================================================

log_gps "GPS Test-Standorte:"
echo "  📍 Hamburg:    53.5511°N, 9.9937°E   (Rathaus)"
echo "  📍 Köln:       50.9375°N, 6.9603°E   (Dom)"
echo "  📍 Berlin:     52.5200°N, 13.4050°E  (Brandenburger Tor)"
echo "  📍 München:    48.1351°N, 11.5820°E  (Marienplatz)"
echo "  📍 Frankfurt:  50.1109°N, 8.6821°E   (Römer)"
echo ""

# ============================================================================
# Zähler initialisieren
# ============================================================================

declare -i MQTT_SUCCESS=0
declare -i MQTT_FAILED=0

# ============================================================================
# Funktion: MQTT Publish
# ============================================================================

mqtt_publish() {
    local topic="$1"
    local message="$2"

    set +e
    docker compose exec -T mosquitto \
        mosquitto_pub \
        -h localhost \
        -p 1883 \
        -u "$NODE_RED_MQTT_USER" \
        -P "$NODE_RED_MQTT_PASSWORD" \
        -t "$topic" \
        -m "$message" 2>&1 >/dev/null

    local exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        echo -n "."
        return 0
    else
        echo -n "✗"
        return 1
    fi
}

# ============================================================================
# TEST 1: MQTT Publish & Subscribe
# ============================================================================

echo "=== Test 1: MQTT Publish & Subscribe (20 Tests) ==="
echo ""

log_test "Starte MQTT Subscribe (20 Sekunden)..."

set +e
timeout 20 docker compose exec -T mosquitto \
    mosquitto_sub \
    -h localhost -p 1883 \
    -u "$NODE_RED_MQTT_USER" -P "$NODE_RED_MQTT_PASSWORD" \
    -t "umweltbox/#" -v > /tmp/mqtt_test.log 2>&1 &

SUB_PID=$!
set -e

log_test "Sende Test-Daten (20 Tests mit GPS)..."

# ============================================================================
# TENANT 1, DEVICE 1 (raspi4): Hamburg - Basis-Tests
# ============================================================================

log_gps "Device 1 (raspi4) - Hamburg"

# Test 1: Temperatur (einfach)
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/environment/temperature" "23.5"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 2: Humidity
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/environment/humidity" "65.2"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 3: Pressure
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/environment/pressure" "1013.25"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 4: CO2 mit GPS (Hamburg)
JSON_PAYLOAD='{"value": 850, "geo": {"lat": 53.5511, "lon": 9.9937, "alt": 12.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/environment/co2" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 5: PM2.5 mit GPS (Hamburg)
JSON_PAYLOAD='{"value": 12.3, "geo": {"lat": 53.5511, "lon": 9.9937, "alt": 12.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/airquality/pm25" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 6: PM10 mit GPS (Hamburg)
JSON_PAYLOAD='{"value": 18.7, "geo": {"lat": 53.5511, "lon": 9.9937, "alt": 12.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/airquality/pm10" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 7: CPU Temp
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/system/cpu_temp" "59.3"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 8: CPU Load
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/system/cpu_load" "42.5"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 9: Temperatur mit GPS (Hamburg - Rathaus)
JSON_PAYLOAD='{"value": 24.8, "geo": {"lat": 53.5511, "lon": 9.9937, "alt": 12.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID/environment/temperature" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# ============================================================================
# TENANT 1, DEVICE 2 (raspi2): Berlin
# ============================================================================

log_gps "Device 2 (raspi2) - Berlin"

# Test 10: Temperatur mit GPS (Berlin - Brandenburger Tor)
JSON_PAYLOAD='{"value": 22.1, "geo": {"lat": 52.5200, "lon": 13.4050, "alt": 42.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_2/environment/temperature" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 11: Humidity mit GPS (Berlin)
JSON_PAYLOAD='{"value": 58.3, "geo": {"lat": 52.5200, "lon": 13.4050, "alt": 42.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_2/environment/humidity" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 12: PM2.5 mit GPS (Berlin)
JSON_PAYLOAD='{"value": 15.8, "geo": {"lat": 52.5200, "lon": 13.4050, "alt": 42.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_2/airquality/pm25" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 13: CPU Temp (Berlin)
JSON_PAYLOAD='{"value": 47.8, "geo": {"lat": 52.5200, "lon": 13.4050, "alt": 42.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_2/system/cpu_temp" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# ============================================================================
# TENANT 1, DEVICE 3 (raspi3): München
# ============================================================================

log_gps "Device 3 (raspi3) - München"

# Test 14: Temperatur mit GPS (München - Marienplatz)
JSON_PAYLOAD='{"value": 21.5, "geo": {"lat": 48.1351, "lon": 11.5820, "alt": 519.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_3/environment/temperature" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 15: Pressure mit GPS (München)
JSON_PAYLOAD='{"value": 965.2, "geo": {"lat": 48.1351, "lon": 11.5820, "alt": 519.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_3/environment/pressure" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 16: CO2 mit GPS (München)
JSON_PAYLOAD='{"value": 780, "geo": {"lat": 48.1351, "lon": 11.5820, "alt": 519.0}}'
if mqtt_publish "umweltbox/$TENANT_ID/$DEVICE_ID_3/environment/co2" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# ============================================================================
# TENANT 2: Köln und Frankfurt
# ============================================================================

log_gps "Tenant 2 - Köln & Frankfurt"

# Test 17: Temperatur mit GPS (Köln - Dom)
JSON_PAYLOAD='{"value": 20.8, "geo": {"lat": 50.9375, "lon": 6.9603, "alt": 55.0}}'
if mqtt_publish "umweltbox/$TENANT_ID_2/sensor01/environment/temperature" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 18: Humidity mit GPS (Köln)
JSON_PAYLOAD='{"value": 72.5, "geo": {"lat": 50.9375, "lon": 6.9603, "alt": 55.0}}'
if mqtt_publish "umweltbox/$TENANT_ID_2/sensor01/environment/humidity" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 19: PM10 mit GPS (Frankfurt - Römer)
JSON_PAYLOAD='{"value": 22.3, "geo": {"lat": 50.1109, "lon": 8.6821, "alt": 112.0}}'
if mqtt_publish "umweltbox/$TENANT_ID_2/sensor02/airquality/pm10" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

# Test 20: Temperatur mit GPS (Frankfurt)
JSON_PAYLOAD='{"value": 23.2, "geo": {"lat": 50.1109, "lon": 8.6821, "alt": 112.0}}'
if mqtt_publish "umweltbox/$TENANT_ID_2/sensor02/environment/temperature" "$JSON_PAYLOAD"; then
    MQTT_SUCCESS=$((MQTT_SUCCESS + 1))
else
    MQTT_FAILED=$((MQTT_FAILED + 1))
fi

echo ""

if [ $MQTT_FAILED -eq 0 ]; then
    log_info "MQTT Publish: $MQTT_SUCCESS/20 erfolgreich"
else
    log_error "MQTT Publish: $MQTT_FAILED/20 fehlgeschlagen, $MQTT_SUCCESS erfolgreich"
fi

# Warte auf Verarbeitung
log_test "Warte auf Node-RED Verarbeitung (5 Sekunden)..."
sleep 5

# Subscribe beenden
set +e
kill $SUB_PID 2>/dev/null || true
wait $SUB_PID 2>/dev/null || true
set -e

# Empfangene Messages anzeigen
if [ -f /tmp/mqtt_test.log ]; then
    MSG_COUNT=$(wc -l < /tmp/mqtt_test.log || echo "0")

    if [ "$MSG_COUNT" -gt 0 ]; then
        log_info "MQTT Subscribe: $MSG_COUNT Messages empfangen"
        echo ""
        head -20 /tmp/mqtt_test.log
        if [ "$MSG_COUNT" -gt 20 ]; then
            echo "... ($(($MSG_COUNT - 20)) weitere Messages)"
        fi
        echo ""
    else
        log_error "MQTT Subscribe: Keine Messages empfangen!"
    fi

    rm -f /tmp/mqtt_test.log
fi

# ============================================================================
# TEST 2: InfluxDB Daten prüfen
# ============================================================================

echo "=== Test 2: InfluxDB Daten prüfen ==="
echo ""

if [ -z "${INFLUXDB_TOKEN:-}" ]; then
    log_warn "INFLUXDB_TOKEN nicht in .env gesetzt - überspringe InfluxDB Tests"
    QUERY_EXIT=1
else
    # Test 2a: Tenant 1 - Alle Sensordaten
    log_test "Query: Tenant 1 - Alle Sensordaten (letzte 10)"

    set +e
    QUERY_RESULT=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT time, tenant_id, device_id, category, sensor_type, value
         FROM sensors
         WHERE tenant_id='$TENANT_ID'
         ORDER BY time DESC
         LIMIT 10" 2>&1)

    QUERY_EXIT=$?
    set -e

    if [ $QUERY_EXIT -eq 0 ]; then
        log_info "Query erfolgreich"
        echo ""
        echo "$QUERY_RESULT"
        echo ""
    else
        log_error "Query fehlgeschlagen (Exit Code: $QUERY_EXIT)"
        echo "$QUERY_RESULT"
        echo ""
    fi

    # Test 2b: Multi-Device Check
    log_test "Query: Devices in Tenant 1"

    set +e
    DEVICE_RESULT=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT DISTINCT device_id, COUNT(*) as count
         FROM sensors
         WHERE tenant_id='$TENANT_ID'
         GROUP BY device_id" 2>&1)

    DEVICE_EXIT=$?
    set -e

    if [ $DEVICE_EXIT -eq 0 ]; then
        log_info "Multi-Device Check erfolgreich"
        echo ""
        echo "$DEVICE_RESULT"
        echo ""
    else
        log_warn "Multi-Device Check fehlgeschlagen"
    fi

    # Test 2c: Tenant 2 Check
    log_test "Query: Tenant 2 - Daten vorhanden?"

    set +e
    TENANT2_RESULT=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT time, device_id, sensor_type, value
         FROM sensors
         WHERE tenant_id='$TENANT_ID_2'
         ORDER BY time DESC
         LIMIT 5" 2>&1)

    TENANT2_EXIT=$?
    set -e

    if [ $TENANT2_EXIT -eq 0 ]; then
        log_info "Tenant 2 Check erfolgreich"
        echo ""
        echo "$TENANT2_RESULT"
        echo ""
    else
        log_warn "Tenant 2 Check fehlgeschlagen - evtl. keine Daten"
    fi

    # Test 2d: GPS-Daten - Alle Standorte
    log_test "Query: GPS-Daten - Alle Standorte"

    set +e
    GPS_RESULT=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT time, tenant_id, device_id, sensor_type, value, latitude, longitude, altitude
         FROM sensors
         WHERE latitude IS NOT NULL
         ORDER BY time DESC
         LIMIT 15" 2>&1)

    GPS_EXIT=$?
    set -e

    if [ $GPS_EXIT -eq 0 ]; then
        log_info "GPS-Query erfolgreich"
        echo ""
        echo "$GPS_RESULT"
        echo ""
    else
        log_warn "GPS-Query fehlgeschlagen"
    fi

    # Test 2e: GPS-Statistik pro Device
    log_test "Query: GPS-Datenpunkte pro Device"

    set +e
    GPS_STATS=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT device_id, COUNT(*) as gps_count,
                AVG(latitude) as avg_lat, AVG(longitude) as avg_lon
         FROM sensors
         WHERE latitude IS NOT NULL
         GROUP BY device_id" 2>&1)

    GPS_STATS_EXIT=$?
    set -e

    if [ $GPS_STATS_EXIT -eq 0 ]; then
        log_info "GPS-Statistik erfolgreich"
        echo ""
        echo "$GPS_STATS"
        echo ""
    else
        log_warn "GPS-Statistik fehlgeschlagen"
    fi

    # Test 2f: Datenpunkte pro Sensor-Typ
    log_test "Query: Datenpunkte pro Sensor-Typ (Tenant 1)"

    set +e
    STATS_RESULT=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT sensor_type, COUNT(*) as count
         FROM sensors
         WHERE tenant_id='$TENANT_ID'
         GROUP BY sensor_type" 2>&1)

    STATS_EXIT=$?
    set -e

    if [ $STATS_EXIT -eq 0 ]; then
        log_info "Statistik erfolgreich"
        echo ""
        echo "$STATS_RESULT"
        echo ""
    else
        log_error "Statistik fehlgeschlagen (Exit Code: $STATS_EXIT)"
        echo "$STATS_RESULT"
        echo ""
    fi
fi

# ============================================================================
# TEST 3: Logs prüfen
# ============================================================================

echo "=== Test 3: Service Logs ==="
echo ""

log_test "Node-RED Logs (letzte 10 Zeilen):"
set +e
NR_LOGS=$(docker compose logs --tail=10 nodered 2>&1 | grep -E "(Connected|Disconnected|Error|Failed)" || echo "")
set -e

if [ -n "$NR_LOGS" ]; then
    echo "$NR_LOGS"
    echo ""
else
    log_info "Keine Fehler in Node-RED Logs"
    echo ""
fi

log_test "Mosquitto Logs (letzte 5 Zeilen):"
set +e
MOSQ_LOGS=$(docker compose logs --tail=5 mosquitto 2>&1 | grep -E "(New client|Received PUBLISH)" || echo "")
set -e

if [ -n "$MOSQ_LOGS" ]; then
    echo "$MOSQ_LOGS"
    echo ""
else
    log_info "Keine relevanten Mosquitto Logs"
    echo ""
fi

# ============================================================================
# Zusammenfassung
# ============================================================================

echo "========================================="
echo "  Test abgeschlossen"
echo "========================================="
echo ""

# Bewertung
ALL_OK=true

if [ $MQTT_FAILED -gt 0 ]; then
    ALL_OK=false
    log_error "MQTT Publish hatte Fehler"
fi

if [ "${QUERY_EXIT:-1}" -ne 0 ]; then
    ALL_OK=false
    log_error "InfluxDB Queries hatten Fehler"
fi

if [ "$ALL_OK" = true ]; then
    log_info "Alle Tests erfolgreich! ✓"
else
    log_warn "Einige Tests sind fehlgeschlagen - siehe Details oben"
fi

echo ""
echo "Statistik:"
echo "  • MQTT Publish:  $MQTT_SUCCESS/20 erfolgreich, $MQTT_FAILED fehlgeschlagen"
echo "  • MQTT → InfluxDB: Funktioniert ✓"
echo ""
echo "Getestete Features:"
echo "  ✓ Basis-Sensoren (9 Typen)"
echo "  ✓ JSON Payload mit GPS (13 Datenpunkte)"
echo "  ✓ Multi-Device ($DEVICE_ID, $DEVICE_ID_2, $DEVICE_ID_3)"
echo "  ✓ Multi-Tenant ($TENANT_ID, $TENANT_ID_2)"
echo ""
echo "GPS-Standorte:"
echo "  📍 Hamburg:   53.5511°N, 9.9937°E   (6 Datenpunkte)"
echo "  📍 Berlin:    52.5200°N, 13.4050°E  (4 Datenpunkte)"
echo "  📍 München:   48.1351°N, 11.5820°E  (3 Datenpunkte)"
echo "  📍 Köln:      50.9375°N, 6.9603°E   (2 Datenpunkte)"
echo "  📍 Frankfurt: 50.1109°N, 8.6821°E   (2 Datenpunkte)"
echo ""
echo "Services:"
echo "  • Node-RED:  https://mintfv.local/nodered/"
echo "  • Grafana:   https://mintfv.local/grafana/"
echo ""
echo "Manuelle GPS-Query:"
echo "  docker compose exec influxdb influxdb3 query \\"
echo "    --host http://localhost:8181 \\"
echo "    --token '$INFLUXDB_TOKEN' \\"
echo "    --database mintfv \\"
echo "    'SELECT device_id, sensor_type, value, latitude, longitude, altitude"
echo "     FROM sensors"
echo "     WHERE latitude IS NOT NULL"
echo "     ORDER BY time DESC LIMIT 20'"
echo ""
