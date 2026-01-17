#!/bin/bash
#
# MintFV Setup Script
# Konfiguriert Node-RED MQTT User und InfluxDB
#

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo "========================================="
echo "  MintFV Setup"
echo "========================================="
echo ""

# ============================================================================
# .env laden
# ============================================================================

log_step "Lade Konfiguration aus .env..."

if [ -f .env ]; then
    source .env
    log_info ".env gefunden"
elif [ -f ../.env ]; then
    source ../.env
    log_info "../.env gefunden"
else
    log_error ".env nicht gefunden!"
    exit 1
fi

# Variablen prüfen
if [ -z "$NODE_RED_MQTT_USER" ] || [ -z "$NODE_RED_MQTT_PASSWORD" ]; then
    log_error "NODE_RED_MQTT_USER oder NODE_RED_MQTT_PASSWORD nicht in .env gesetzt!"
    exit 1
fi

if [ -z "$INFLUXDB_TOKEN" ]; then
    log_warn "INFLUXDB_TOKEN nicht in .env gesetzt - InfluxDB Tests werden übersprungen"
fi

log_info "MQTT User: $NODE_RED_MQTT_USER"
echo ""

# ============================================================================
# SETUP: Node-RED MQTT User in Mosquitto
# ============================================================================

log_step "Prüfe Mosquitto MQTT User..."

# Prüfe ob User existiert
if docker compose exec -T mosquitto grep -q "^$NODE_RED_MQTT_USER:" /mosquitto/config/mosquitto.passwd 2>/dev/null; then
    log_info "MQTT User '$NODE_RED_MQTT_USER' existiert bereits"
else
    log_warn "MQTT User '$NODE_RED_MQTT_USER' fehlt - erstelle..."
    
    # User erstellen
    docker compose exec -T mosquitto \
        mosquitto_passwd -b /mosquitto/config/mosquitto.passwd \
        "$NODE_RED_MQTT_USER" "$NODE_RED_MQTT_PASSWORD"
    
    if [ $? -eq 0 ]; then
        log_info "MQTT User erstellt"
        
        # Mosquitto neu laden
        log_step "Starte Mosquitto neu..."
        docker compose restart mosquitto
        sleep 3
        log_info "Mosquitto neugestartet"
    else
        log_error "Fehler beim Erstellen des MQTT Users!"
        exit 1
    fi
fi

echo ""

# ============================================================================
# Node-RED Konfiguration prüfen
# ============================================================================

log_step "Prüfe Node-RED MQTT Konfiguration..."

# Prüfe ob Node-RED läuft
if ! docker compose ps nodered | grep -q "Up"; then
    log_error "Node-RED läuft nicht!"
    exit 1
fi

log_info "Node-RED läuft"

echo ""
log_warn "WICHTIG: Setze MQTT Credentials in Node-RED!"
echo ""
echo "  1. Öffne: https://mintfv.local/nodered/"
echo "  2. Doppelklick auf MQTT-Node (blau)"
echo "  3. Klick auf Stift-Symbol bei 'Server'"
echo "  4. Tab 'Security':"
echo "     Username: $NODE_RED_MQTT_USER"
echo "     Password: $NODE_RED_MQTT_PASSWORD"
echo "  5. 'Update' → 'Done' → 'Deploy' (roter Button)"
echo ""
read -p "Drücke ENTER wenn Node-RED konfiguriert ist..." dummy

echo ""

# ============================================================================
# InfluxDB Setup prüfen
# ============================================================================

if [ -n "$INFLUXDB_TOKEN" ]; then
    log_step "Prüfe InfluxDB Setup..."
    
    # Prüfe ob InfluxDB läuft
    if ! docker compose ps influxdb | grep -q "Up"; then
        log_error "InfluxDB läuft nicht!"
        exit 1
    fi
    
    # Prüfe ob Database existiert
    DB_CHECK=$(docker compose exec -T influxdb \
        influxdb3 query \
        --host http://localhost:8181 \
        --token "$INFLUXDB_TOKEN" \
        --database mintfv \
        "SELECT 1" 2>&1 || echo "FAILED")
    
    if echo "$DB_CHECK" | grep -q "FAILED\|error\|Error"; then
        log_error "InfluxDB Database 'mintfv' nicht erreichbar!"
        echo "$DB_CHECK"
        exit 1
    else
        log_info "InfluxDB Database 'mintfv' OK"
    fi
else
    log_warn "InfluxDB Setup übersprungen (kein Token)"
fi

echo ""

# ============================================================================
# Setup abgeschlossen - starte Test
# ============================================================================

log_info "Setup abgeschlossen!"
echo ""
echo "========================================="
echo "  Starte Test-Script..."
echo "========================================="
echo ""

# Test-Script ausführen
if [ -f ./test_mqtt_pipeline.sh ]; then
    chmod +x ./test_mqtt_pipeline.sh
    ./test_mqtt_pipeline.sh
elif [ -f ./test_mqtt_pipeline_5levels.sh ]; then
    chmod +x ./test_mqtt_pipeline_5levels.sh
    ./test_mqtt_pipeline_5levels.sh
else
    log_warn "Test-Script nicht gefunden - überspringe Tests"
    echo ""
    echo "Manuelle Tests:"
    echo "  1. MQTT Publish:"
    echo "     docker compose exec mosquitto mosquitto_pub \\"
    echo "       -h localhost -p 1883 \\"
    echo "       -u '$NODE_RED_MQTT_USER' -P '$NODE_RED_MQTT_PASSWORD' \\"
    echo "       -t 'umweltbox/de-hh-privat-peddy/raspi4/environment/temperature' \\"
    echo "       -m '23.5'"
    echo ""
    echo "  2. InfluxDB Query:"
    echo "     docker compose exec influxdb influxdb3 query \\"
    echo "       --host http://localhost:8181 \\"
    echo "       --token '$INFLUXDB_TOKEN' \\"
    echo "       --database mintfv \\"
    echo "       'SELECT * FROM sensors LIMIT 10'"
    echo ""
fi
