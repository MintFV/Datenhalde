#!/bin/bash
# ============================================================================
# MintFV Playwright Test Runner
# Runs Playwright tests in a Docker container on the mintfv-network.
#
# Usage:
#   ./run-tests.sh              # Run all tests
#   ./run-tests.sh landing      # Run only landing page tests
#   ./run-tests.sh selfservice  # Run only selfservice tests
#   ./run-tests.sh grafana      # Run only Grafana tests
#   ./run-tests.sh nodered      # Run only Node-RED tests
#   ./run-tests.sh influxdb     # Run only InfluxDB tests
#   ./run-tests.sh mosquitto    # Run only Mosquitto tests
#   ./run-tests.sh nginx        # Run only nginx security tests
# ============================================================================

set -euo pipefail
cd "$(dirname "$0")"

CONTAINER_NAME="mintfv-playwright"
NETWORK="mintfv_mintfv-network"
IMAGE="mintfv-playwright-tests"

# Build the test image
echo "=== Building Playwright test image ==="
docker build -t "$IMAGE" . --quiet

# Determine which test to run
TEST_CMD="npx playwright test"
if [[ "${1:-}" != "" ]]; then
    case "$1" in
        landing)     TEST_CMD="npx playwright test specs/landing.spec.ts" ;;
        selfservice) TEST_CMD="npx playwright test specs/selfservice.spec.ts" ;;
        grafana)     TEST_CMD="npx playwright test specs/grafana.spec.ts" ;;
        nodered)     TEST_CMD="npx playwright test specs/nodered.spec.ts" ;;
        influxdb)    TEST_CMD="npx playwright test specs/influxdb.spec.ts" ;;
        mosquitto)   TEST_CMD="npx playwright test specs/mosquitto.spec.ts" ;;
        nginx)       TEST_CMD="npx playwright test specs/nginx-security.spec.ts" ;;
        *)           TEST_CMD="npx playwright test $*" ;;
    esac
fi

# Remove old container if exists
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "=== Running: $TEST_CMD ==="
echo ""

# Run tests in container on the mintfv network
docker run \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --rm \
    -v "$(pwd)/report:/tests/report" \
    "$IMAGE" \
    $TEST_CMD

echo ""
echo "=== HTML report available in tests/report/ ==="
