#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

env_value() {
	grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-
}

SMOKE_USER=$(env_value MQTT_SMOKE_USER)
SMOKE_PASS=$(env_value MQTT_SMOKE_PASS)
[ -n "$SMOKE_USER" ] || fail "MQTT_SMOKE_USER fehlt in .env"
[ -n "$SMOKE_PASS" ] || fail "MQTT_SMOKE_PASS fehlt in .env"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "${ACL_FILE:-}" ]; then
	cp "$ACL_FILE" "$TMP/acl"
else
	docker compose exec -T mosquitto cat /mosquitto/config/mosquitto.acl >"$TMP/acl"
fi

extract_rules() {
	awk -v user="$1" '
        $0 == "user " user { inside = 1; next }
        inside && /^user / { inside = 0 }
        inside && /^topic / { print }
    ' "$TMP/acl"
}

EXPECTED_SMOKE=$(printf '%s\n' \
	'topic write smoketest/mintfv-smoketest/#' \
	'topic read smoketest/mintfv-smoketest/#' \
	'topic read umweltbox/de-hh-mintfv-uwbox23/#' \
	'topic read $SYS/broker/version')

EXPECTED_REF=$(printf '%s\n' \
	'topic write umweltbox/de-hh-mintfv-uwbox23/#' \
	'topic read umweltbox/de-hh-mintfv-uwbox23/cmnd/#' \
	'topic read $SYS/broker/version')

[ "$(extract_rules mintfv-smoketest)" = "$EXPECTED_SMOKE" ] || fail "Testidentität hat nicht die erwarteten vier Regeln"
[ "$(extract_rules de-hh-mintfv-uwbox23)" = "$EXPECTED_REF" ] || fail "Referenzgerät uwbox23 ist verändert"
echo "PASS: statische ACL-Prüfung"

PAYLOAD="ping-$(date +%s)"
docker compose exec -T -e U="$SMOKE_USER" -e P="$SMOKE_PASS" mosquitto \
	sh -c 'exec mosquitto_sub -h 127.0.0.1 -p 1883 -u "$U" -P "$P" -t "smoketest/mintfv-smoketest/#" -C 1 -W 15' \
	>"$TMP/sub_out" 2>"$TMP/sub_err" &
SUB_PID=$!
sleep 1
docker compose exec -T -e U="$SMOKE_USER" -e P="$SMOKE_PASS" mosquitto \
	sh -c 'exec mosquitto_pub -h 127.0.0.1 -p 1883 -u "$U" -P "$P" -t "smoketest/mintfv-smoketest/ping" -m "$1"' \
	sh "$PAYLOAD" || fail "MQTT-Publish fehlgeschlagen"
wait "$SUB_PID" || fail "MQTT-Round-Trip fehlgeschlagen"
grep -q "$PAYLOAD" "$TMP/sub_out" || fail "Testnachricht nicht zugestellt"
echo "PASS: MQTT-Round-Trip"

COUNT=$(
	docker compose exec -T influxdb sh -s <<'INNER'
T=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /var/lib/influxdb3/tokens/admin.token | head -1)
influxdb3 query -d mintfv --token "$T" --format csv "SELECT count(*) AS n FROM sensors WHERE time > now() - interval '30 minutes' AND tenant_id = 'de-hh-mintfv-uwbox23'" | tail -n +2 | head -n 1 | cut -d, -f1
INNER
)
case "$COUNT" in
'' | *[!0-9]*) fail "InfluxDB-Abfrage lieferte keinen Zähler" ;;
esac
[ "$COUNT" -gt 0 ] || fail "Keine aktuellen uwbox23-Daten in InfluxDB"
echo "PASS: InfluxDB-Canary ($COUNT Punkte / 30 min)"

echo "SMOKE_OK"
