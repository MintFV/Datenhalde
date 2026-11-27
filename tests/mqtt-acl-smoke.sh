#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

RESULT_TARGET="${SMOKETEST_RESULT_TARGET:-prod}"
RESULT_TOPIC="smoketest/mintfv-smoketest/results/$RESULT_TARGET"

env_value() {
	grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-
}

json_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

publish_result() {
	local check="$1" ok="$2" count="${3:-}"
	local user pass fields payload
	user="${SMOKETEST_RESULT_USER:-$(env_value MQTT_SMOKE_USER)}"
	pass="${SMOKETEST_RESULT_PASS:-$(env_value MQTT_SMOKE_PASS)}"
	fields=""
	if [ -n "$count" ]; then
		fields="$fields,\"canary_count\":$count"
	fi
	if [ "$RESULT_TARGET" = "ci" ]; then
		fields="$fields,\"run_id\":\"$(json_escape "${GITHUB_RUN_ID:-}")\""
		fields="$fields,\"sha\":\"$(json_escape "${GITHUB_SHA:-}")\""
		fields="$fields,\"ref\":\"$(json_escape "${GITHUB_REF:-}")\""
	fi
	payload="{\"check\":\"$check\",\"ok\":$ok$fields}"
	if [ "$RESULT_TARGET" = "ci" ]; then
		if ! docker run --rm -e U="$user" -e P="$pass" eclipse-mosquitto:2.0.22 \
			sh -c 'mosquitto_pub -h mintfv.peddy.net -p 8883 --cafile /etc/ssl/certs/ca-certificates.crt -u "$U" -P "$P" -t "$1" -m "$2"' \
			sh "$RESULT_TOPIC" "$payload" >/dev/null 2>&1; then
			echo "WARN: Ergebnispunkt $check konnte nicht veröffentlicht werden" >&2
		fi
	else
		if ! docker compose exec -T -e U="$user" -e P="$pass" mosquitto \
			sh -c 'mosquitto_pub -h 127.0.0.1 -p 1883 -u "$U" -P "$P" -t "$1" -m "$2"' \
			sh "$RESULT_TOPIC" "$payload" >/dev/null 2>&1; then
			echo "WARN: Ergebnispunkt $check konnte nicht veröffentlicht werden" >&2
		fi
	fi
}

fail() {
	local check="$1"
	shift
	publish_result "$check" 0
	publish_result overall 0
	echo "FAIL: $*" >&2
	exit 1
}

SMOKE_USER=$(env_value MQTT_SMOKE_USER)
SMOKE_PASS=$(env_value MQTT_SMOKE_PASS)
[ -n "$SMOKE_USER" ] || fail mqtt "MQTT_SMOKE_USER fehlt in .env"
[ -n "$SMOKE_PASS" ] || fail mqtt "MQTT_SMOKE_PASS fehlt in .env"

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

[ "$(extract_rules mintfv-smoketest)" = "$EXPECTED_SMOKE" ] || fail acl "Testidentität hat nicht die erwarteten vier Regeln"
[ "$(extract_rules de-hh-mintfv-uwbox23)" = "$EXPECTED_REF" ] || fail acl "Referenzgerät uwbox23 ist verändert"
publish_result acl 1
echo "PASS: statische ACL-Prüfung"

PAYLOAD="ping-$(date +%s)"
docker compose exec -T -e U="$SMOKE_USER" -e P="$SMOKE_PASS" mosquitto \
	sh -c 'exec mosquitto_sub -h 127.0.0.1 -p 1883 -u "$U" -P "$P" -t "smoketest/mintfv-smoketest/#" -C 1 -W 15' \
	>"$TMP/sub_out" 2>"$TMP/sub_err" &
SUB_PID=$!
sleep 1
docker compose exec -T -e U="$SMOKE_USER" -e P="$SMOKE_PASS" mosquitto \
	sh -c 'exec mosquitto_pub -h 127.0.0.1 -p 1883 -u "$U" -P "$P" -t "smoketest/mintfv-smoketest/ping" -m "$1"' \
	sh "$PAYLOAD" || fail mqtt "MQTT-Publish fehlgeschlagen"
wait "$SUB_PID" || fail mqtt "MQTT-Round-Trip fehlgeschlagen"
grep -q "$PAYLOAD" "$TMP/sub_out" || fail mqtt "Testnachricht nicht zugestellt"
publish_result mqtt 1
echo "PASS: MQTT-Round-Trip"

COUNT=$(
	docker compose exec -T influxdb sh -s <<'INNER'
T=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /var/lib/influxdb3/tokens/admin.token | head -1)
influxdb3 query -d mintfv --token "$T" --format csv "SELECT count(*) AS n FROM sensors WHERE time > now() - interval '30 minutes' AND tenant_id = 'de-hh-mintfv-uwbox23'" | tail -n +2 | head -n 1 | cut -d, -f1
INNER
)
case "$COUNT" in
'' | *[!0-9]*) fail canary "InfluxDB-Abfrage lieferte keinen Zähler" ;;
esac
[ "$COUNT" -gt 0 ] || fail canary "Keine aktuellen uwbox23-Daten in InfluxDB"
publish_result canary 1 "$COUNT"
echo "PASS: InfluxDB-Canary ($COUNT Punkte / 30 min)"

publish_result overall 1
echo "SMOKE_OK"
