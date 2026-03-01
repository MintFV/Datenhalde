#!/bin/bash
#
# MintFV Grafana Dashboard Auto-Share Script
# Provisions dashboard and automatically enables public sharing
#
# Usage: ./grafana_auto_share.sh <dashboard.json>
#

set -e

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if dashboard file is provided
if [ -z "$1" ]; then
    log_error "Usage: $0 <dashboard.json>"
    exit 1
fi

DASHBOARD_FILE="$1"

if [ ! -f "$DASHBOARD_FILE" ]; then
    log_error "Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

log_info "Starting Grafana Dashboard Auto-Share Process"
log_info "Dashboard file: $DASHBOARD_FILE"
log_info "Grafana URL: $GRAFANA_URL"

# Step 1: Extract dashboard UID from JSON
log_info "Extracting dashboard UID..."
DASHBOARD_UID=$(jq -r '.uid // empty' "$DASHBOARD_FILE")

if [ -z "$DASHBOARD_UID" ]; then
    log_error "No UID found in dashboard JSON. Please add a 'uid' field."
    exit 1
fi

log_success "Dashboard UID: $DASHBOARD_UID"

# Step 2: Create API key (if not exists)
log_info "Creating Grafana API key..."

API_KEY_RESPONSE=$(curl -s -X POST     -H "Content-Type: application/json"     -u "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}"     -d '{"name":"auto-share-'$(date +%s)'", "role":"Admin"}'     "${GRAFANA_URL}/api/auth/keys" 2>/dev/null || echo '{"key":""}')

API_KEY=$(echo "$API_KEY_RESPONSE" | jq -r '.key // empty')

if [ -z "$API_KEY" ]; then
    log_warning "Could not create new API key, trying with basic auth..."
    AUTH_HEADER="Authorization: Basic $(echo -n ${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD} | base64)"
else
    log_success "API key created"
    AUTH_HEADER="Authorization: Bearer ${API_KEY}"
fi

# Step 3: Import/Update Dashboard
log_info "Importing dashboard to Grafana..."

DASHBOARD_PAYLOAD=$(jq -n     --argjson dashboard "$(cat $DASHBOARD_FILE)"     '{
        dashboard: $dashboard,
        overwrite: true,
        message: "Auto-provisioned with public share"
    }')

IMPORT_RESPONSE=$(curl -s -X POST     -H "Content-Type: application/json"     -H "$AUTH_HEADER"     -d "$DASHBOARD_PAYLOAD"     "${GRAFANA_URL}/api/dashboards/db")

IMPORT_STATUS=$(echo "$IMPORT_RESPONSE" | jq -r '.status // "error"')

if [ "$IMPORT_STATUS" != "success" ]; then
    log_error "Failed to import dashboard"
    echo "$IMPORT_RESPONSE" | jq .
    exit 1
fi

log_success "Dashboard imported successfully"

DASHBOARD_URL=$(echo "$IMPORT_RESPONSE" | jq -r '.url // empty')
log_info "Dashboard URL: ${GRAFANA_URL}${DASHBOARD_URL}"

# Step 4: Enable Public Dashboard
log_info "Enabling public sharing..."

PUBLIC_SHARE_PAYLOAD='{
    "isEnabled": true,
    "share": "public",
    "annotationsEnabled": false,
    "timeSelectionEnabled": true
}'

PUBLIC_RESPONSE=$(curl -s -X POST     -H "Content-Type: application/json"     -H "$AUTH_HEADER"     -d "$PUBLIC_SHARE_PAYLOAD"     "${GRAFANA_URL}/api/dashboards/uid/${DASHBOARD_UID}/public-dashboards")

PUBLIC_UID=$(echo "$PUBLIC_RESPONSE" | jq -r '.uid // empty')
ACCESS_TOKEN=$(echo "$PUBLIC_RESPONSE" | jq -r '.accessToken // empty')

if [ -z "$ACCESS_TOKEN" ]; then
    log_error "Failed to enable public sharing"
    echo "$PUBLIC_RESPONSE" | jq .
    exit 1
fi

log_success "Public sharing enabled"

# Step 5: Output results
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "Dashboard Auto-Share Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Dashboard UID:     ${DASHBOARD_UID}"
echo "  Public Share UID:  ${PUBLIC_UID}"
echo ""
echo "  📊 Dashboard URL (authenticated):"
echo "     ${GRAFANA_URL}${DASHBOARD_URL}"
echo ""
echo "  🌍 Public URL (no login required):"
echo "     ${GRAFANA_URL}/public-dashboards/${ACCESS_TOKEN}"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Optional: Save public URL to file
PUBLIC_URL_FILE="${DASHBOARD_FILE%.json}.public-url.txt"
echo "${GRAFANA_URL}/public-dashboards/${ACCESS_TOKEN}" > "$PUBLIC_URL_FILE"
log_info "Public URL saved to: $PUBLIC_URL_FILE"
