#!/bin/bash
# ============================================================================
# MintFV Validation Script
# Führe nach Setup aus um alle Services zu validieren
# ============================================================================

set -e

DOMAIN="${DOMAIN:-mintfv.peddy.net}"
TOKEN=""

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "MintFV Validation Suite"
echo "=========================================="

# Token aus Datei lesen (wenn vorhanden)
if [ -f "./influxdb/tokens/admin.token" ]; then
    TOKEN=$(cat ./influxdb/tokens/admin.token 2>/dev/null | jq -r '.token' 2>/dev/null || echo "")
fi

# 1. HTTPS & nginx
echo -e "\n${BLUE}1. Testing HTTPS...${NC}"
if curl -fsS https://$DOMAIN > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ HTTPS working${NC}"
else
    echo -e "  ${RED}✗ HTTPS failed${NC}"
fi

# 2. Grafana
echo -e "\n${BLUE}2. Testing Grafana...${NC}"
if curl -u admin:admin -fsS https://$DOMAIN/grafana/api/health 2>/dev/null | jq -e '.database == "ok"' >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Grafana working${NC}"
else
    echo -e "  ${YELLOW}⚠ Grafana health check inconclusive${NC}"
fi

# 3. InfluxDB Health
echo -e "\n${BLUE}3. Testing InfluxDB...${NC}"
if [ -n "$TOKEN" ]; then
    if curl -fsS -H "Authorization: Bearer $TOKEN" \
      https://$DOMAIN/influxdb/health 2>/dev/null | jq -e '.status == "pass"' >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ InfluxDB working${NC}"
    else
        echo -e "  ${YELLOW}⚠ InfluxDB health check inconclusive${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ InfluxDB token not found (skip)${NC}"
fi

# 4. Node-RED
echo -e "\n${BLUE}4. Testing Node-RED...${NC}"
if curl -fsS https://$DOMAIN/nodered/ 2>/dev/null | grep -q "Node-RED"; then
    echo -e "  ${GREEN}✓ Node-RED working${NC}"
else
    echo -e "  ${YELLOW}⚠ Node-RED not enabled or not responding${NC}"
fi

# 5. MQTT
echo -e "\n${BLUE}5. Testing MQTT...${NC}"
if docker compose ps mosquitto 2>/dev/null | grep -q "Up"; then
    if command -v mosquitto_sub &> /dev/null; then
        if timeout 5 mosquitto_sub -h $DOMAIN -p 1883 -u monitoring -P "monitor2024!" \
          -t '$SYS/broker/version' -C 1 &>/dev/null; then
            echo -e "  ${GREEN}✓ MQTT working${NC}"
        else
            echo -e "  ${YELLOW}⚠ MQTT auth issue or timeout${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ mosquitto_sub not installed (skip)${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ MQTT not enabled${NC}"
fi

# 6. MQTT TLS (Port 8883)
echo -e "\n${BLUE}6. Testing MQTT over TLS...${NC}"
if command -v openssl &> /dev/null; then
    if openssl s_client -connect $DOMAIN:8883 -servername $DOMAIN </dev/null 2>&1 | grep -q "Verify return code: 0"; then
        echo -e "  ${GREEN}✓ MQTT TLS working${NC}"
    else
        echo -e "  ${YELLOW}⚠ MQTT TLS certificate issue${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ openssl not installed (skip)${NC}"
fi

# 7. Container Status
echo -e "\n${BLUE}7. Container Status:${NC}"
echo "=========================================="
docker compose ps 2>/dev/null || echo "docker compose not available"

# 8. Recent Errors
echo ""
echo "=========================================="
echo -e "${BLUE}8. Recent Errors (last 50 lines):${NC}"
echo "=========================================="
ERROR_COUNT=$(docker compose logs --tail=50 2>/dev/null | grep -iE "error|failed|critical" | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}No errors found ✓${NC}"
else
    echo -e "${YELLOW}Found $ERROR_COUNT error lines:${NC}"
    docker compose logs --tail=50 2>/dev/null | grep -iE "error|failed|critical" | head -10
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Validation complete!${NC}"
echo "=========================================="
