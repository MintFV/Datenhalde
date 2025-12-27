#!/bin/bash
# ACL Multi-Tenant Test-Skript für MintFV Mosquitto Broker
#
# KRITISCH: Dieses Skript validiert ACLs über Broker-Logs,
# NICHT über Client-Return-Codes (die sind bei QoS 0 immer SUCCESS)!
#
# Verwendung:
#   ./test-acl.sh                 # Alle Tests
#   ./test-acl.sh --tenant tenant-a   # Nur Tenant A
#   ./test-acl.sh --verbose       # Mit Debug-Output

set -euo pipefail

# ============================================================================
# Konfiguration
# ============================================================================

MQTT_HOST="mintfv.peddy.net"
MQTT_PORT="1883"
CONTAINER_NAME="mintfv-mosquitto"
LOG_TIMEOUT=2  # Sekunden zum Warten auf Log-Einträge

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Zähler
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Flags
VERBOSE=false
SPECIFIC_TENANT=""

# ============================================================================
# Funktionen
# ============================================================================

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST $((TESTS_TOTAL + 1))]${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "  ${BLUE}ℹ${NC} $1"
    fi
}

# Prüfe ob Container läuft
check_prerequisites() {
    print_header "🔍 Prerequisites Check"

    # Docker Container Status
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}ERROR:${NC} Container ${CONTAINER_NAME} läuft nicht!"
        echo "Starte Container mit: docker compose up -d mosquitto"
        exit 1
    fi
    print_success "Container ${CONTAINER_NAME} läuft"

    # mosquitto_pub verfügbar?
    if ! command -v mosquitto_pub &> /dev/null; then
        echo -e "${RED}ERROR:${NC} mosquitto_pub nicht gefunden!"
        echo "Installation: sudo apt-get install mosquitto-clients"
        exit 1
    fi
    print_success "mosquitto_pub verfügbar"

    # Broker erreichbar?
    if ! timeout 3 bash -c "</dev/tcp/${MQTT_HOST}/${MQTT_PORT}" 2>/dev/null; then
        echo -e "${RED}ERROR:${NC} MQTT Broker ${MQTT_HOST}:${MQTT_PORT} nicht erreichbar!"
        exit 1
    fi
    print_success "Broker ${MQTT_HOST}:${MQTT_PORT} erreichbar"

    echo ""
}

# Hole letzten Log-Eintrag des Brokers
get_broker_log() {
    docker logs --tail=20 "${CONTAINER_NAME}" 2>&1 | tail -5
}

# Teste Publish mit Erwartung
test_publish() {
    local user=$1
    local password=$2
    local topic=$3
    local expected_result=$4  # "ALLOW" oder "DENY"
    local test_name=$5

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_test "$test_name"

    # Logs leeren (letzte Zeile merken)
    local log_before=$(docker logs --tail=1 "${CONTAINER_NAME}" 2>&1 | tail -1)

    # Publish durchführen (QoS 0 - gibt immer SUCCESS zurück!)
    print_info "mosquitto_pub -h ${MQTT_HOST} -u ${user} -t ${topic} -m 'test'"
    mosquitto_pub -h "${MQTT_HOST}" -p "${MQTT_PORT}" \
        -u "${user}" -P "${password}" \
        -t "${topic}" -m "test_$(date +%s)" \
        &>/dev/null

    # Warte auf Log-Eintrag
    sleep "${LOG_TIMEOUT}"

    # Hole neue Logs
    local log_after=$(docker logs --since "${LOG_TIMEOUT}s" "${CONTAINER_NAME}" 2>&1)

    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Log Output:${NC}"
        echo "$log_after" | tail -5 | sed 's/^/    /'
    fi

    # Validierung
    if [ "$expected_result" = "ALLOW" ]; then
        # Erwarte "Received PUBLISH" (oder keinen Denied-Eintrag)
        if echo "$log_after" | grep -q "Denied PUBLISH.*${user}"; then
            print_fail "Publish wurde BLOCKIERT (erwartet: erlaubt)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        else
            print_success "Publish wurde ERLAUBT"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    elif [ "$expected_result" = "DENY" ]; then
        # Erwarte "Denied PUBLISH"
        if echo "$log_after" | grep -q "Denied PUBLISH.*${user}.*${topic}"; then
            print_success "Publish wurde BLOCKIERT (korrekt)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_fail "Publish wurde NICHT blockiert (erwartet: denied)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

# ============================================================================
# Test-Suiten
# ============================================================================

test_master_admin() {
    print_header "🔑 Master Admin Tests"

    test_publish "master-admin" "master2024!" \
        "tenant/tenant-a/test" "ALLOW" \
        "Master kann in Tenant A schreiben"

    test_publish "master-admin" "master2024!" \
        "tenant/tenant-b/test" "ALLOW" \
        "Master kann in Tenant B schreiben"

    test_publish "master-admin" "master2024!" \
        "global/test" "ALLOW" \
        "Master kann in globale Topics schreiben"
}

test_tenant_a() {
    print_header "🏢 Tenant A Tests"

    # Admin Tests
    test_publish "tenant-a-admin" "alpha2024!" \
        "tenant/tenant-a/admin/commands" "ALLOW" \
        "Tenant-A Admin kann in eigenen Namespace schreiben"

    test_publish "tenant-a-admin" "alpha2024!" \
        "tenant/tenant-b/admin/commands" "DENY" \
        "Tenant-A Admin kann NICHT in Tenant B schreiben"

    # Sensor Tests
    test_publish "tenant-a-sensor01" "sensor01" \
        "tenant/tenant-a/sensor01/temperature" "ALLOW" \
        "Sensor01 kann in eigenen Topic schreiben"

    test_publish "tenant-a-sensor01" "sensor01" \
        "tenant/tenant-a/sensor02/temperature" "DENY" \
        "Sensor01 kann NICHT in fremden Sensor-Topic schreiben"

    test_publish "tenant-a-sensor01" "sensor01" \
        "tenant/tenant-b/sensor01/temperature" "DENY" \
        "Sensor01 kann NICHT in anderen Tenant schreiben"

    # Node-RED Tests
    test_publish "tenant-a-nodered" "nodered-a" \
        "tenant/tenant-a/flows/output" "ALLOW" \
        "Node-RED kann in Tenant-A schreiben"

    test_publish "tenant-a-nodered" "nodered-a" \
        "tenant/tenant-b/flows/output" "DENY" \
        "Node-RED kann NICHT in Tenant-B schreiben"
}

test_tenant_b() {
    print_header "🏢 Tenant B Tests"

    test_publish "tenant-b-admin" "beta2024!" \
        "tenant/tenant-b/test" "ALLOW" \
        "Tenant-B Admin kann in eigenen Namespace schreiben"

    test_publish "tenant-b-sensor01" "sensor01" \
        "tenant/tenant-b/sensor01/humidity" "ALLOW" \
        "Tenant-B Sensor kann in eigenen Topic schreiben"

    test_publish "tenant-b-sensor01" "sensor01" \
        "tenant/tenant-a/sensor01/humidity" "DENY" \
        "Tenant-B Sensor kann NICHT in Tenant-A schreiben"
}

test_tenant_c() {
    print_header "🏢 Tenant C Tests"

    test_publish "tenant-c-admin" "gamma2024!" \
        "tenant/tenant-c/test" "ALLOW" \
        "Tenant-C Admin kann in eigenen Namespace schreiben"

    test_publish "tenant-c-sensor02" "sensor02" \
        "tenant/tenant-c/sensor02/pressure" "ALLOW" \
        "Tenant-C Sensor02 kann in eigenen Topic schreiben"
}

test_monitoring() {
    print_header "📊 Monitoring User Tests"

    # Monitoring user sollte NICHT publishen können
    test_publish "monitoring" "monitor2024!" \
        "test/monitoring" "DENY" \
        "Monitoring kann NICHT publishen (read-only)"
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Parse Argumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --tenant|-t)
                SPECIFIC_TENANT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --verbose, -v         Verbose output mit Logs"
                echo "  --tenant, -t TENANT   Nur bestimmten Tenant testen"
                echo "  --help, -h            Diese Hilfe"
                echo ""
                echo "Tenants: tenant-a, tenant-b, tenant-c, master, monitoring"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Header
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   MintFV Mosquitto ACL Test Suite                        ║
║   Multi-Tenant MQTT Access Control Validation            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${YELLOW}⚠️  WICHTIG:${NC} ACL-Validierung erfolgt über Broker-Logs!"
    echo -e "           Client-Return-Codes (QoS 0) sind NICHT aussagekräftig.\n"

    # Prerequisites
    check_prerequisites

    # Tests ausführen
    if [ -z "$SPECIFIC_TENANT" ]; then
        # Alle Tests
        test_master_admin
        test_tenant_a
        test_tenant_b
        test_tenant_c
        test_monitoring
    else
        # Spezifischer Tenant
        case $SPECIFIC_TENANT in
            master)
                test_master_admin
                ;;
            tenant-a)
                test_tenant_a
                ;;
            tenant-b)
                test_tenant_b
                ;;
            tenant-c)
                test_tenant_c
                ;;
            monitoring)
                test_monitoring
                ;;
            *)
                echo -e "${RED}ERROR:${NC} Unknown tenant: $SPECIFIC_TENANT"
                exit 1
                ;;
        esac
    fi

    # Zusammenfassung
    print_header "📋 Test Summary"
    echo -e "Total Tests:  ${TESTS_TOTAL}"
    echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ Alle Tests bestanden!${NC}\n"
        exit 0
    else
        echo -e "\n${RED}✗ ${TESTS_FAILED} Test(s) fehlgeschlagen!${NC}\n"
        exit 1
    fi
}

main "$@"
