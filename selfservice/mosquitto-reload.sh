#!/bin/sh
# mosquitto-reload Sidecar
# Überwacht ein Signal-Verzeichnis und sendet SIGHUP an Mosquitto (PID 1)
# wenn eine Trigger-Datei geschrieben wird.
#
# Voraussetzung: pid: "service:mosquitto" im docker-compose.yaml
# Dadurch teilen sich dieser Container und Mosquitto den PID-Namespace.

set -e

WATCH_DIR="/watch"
MOSQUITTO_PID_FILE="/mosquitto/data/mosquitto.pid"

echo "=== Mosquitto Reload Sidecar ==="
echo "Watching: ${WATCH_DIR}"

# Sicherstellen, dass das Verzeichnis existiert und beschreibbar ist
if [ ! -d "${WATCH_DIR}" ]; then
    echo "FEHLER: ${WATCH_DIR} existiert nicht"
    exit 1
fi

# inotifywait überwacht close_write Events
while true; do
    # Warte auf Datei-Änderungen
    inotifywait -q -e close_write "${WATCH_DIR}" 2>/dev/null || {
        echo "inotifywait fehlt oder Fehler, Fallback auf Polling..."
        # Fallback: Polling alle 5 Sekunden
        while true; do
            if [ -f "${WATCH_DIR}/reload.trigger" ]; then
                TRIGGER_TIME=$(cat "${WATCH_DIR}/reload.trigger" 2>/dev/null || echo "unknown")
                echo "[$(date)] Reload-Trigger erkannt (${TRIGGER_TIME}), sende SIGHUP..."
                # Finde Mosquitto PID im geteilten PID-Namespace
                MOSQ_PID=$(pgrep -x mosquitto 2>/dev/null || echo "")
                if [ -n "${MOSQ_PID}" ]; then
                    kill -HUP ${MOSQ_PID}
                    echo "[$(date)] SIGHUP an Mosquitto (PID ${MOSQ_PID}) gesendet"
                else
                    echo "[$(date)] WARNUNG: Mosquitto-Prozess nicht gefunden"
                fi
                rm -f "${WATCH_DIR}/reload.trigger"
            fi
            sleep 5
        done
    }

    # inotifywait hat ein Event erkannt
    if [ -f "${WATCH_DIR}/reload.trigger" ]; then
        TRIGGER_TIME=$(cat "${WATCH_DIR}/reload.trigger" 2>/dev/null || echo "unknown")
        echo "[$(date)] Reload-Trigger erkannt (${TRIGGER_TIME}), sende SIGHUP..."

        # Finde Mosquitto PID im geteilten PID-Namespace
        MOSQ_PID=$(pgrep -x mosquitto 2>/dev/null || echo "")
        if [ -n "${MOSQ_PID}" ]; then
            kill -HUP ${MOSQ_PID}
            echo "[$(date)] SIGHUP an Mosquitto (PID ${MOSQ_PID}) gesendet"
        else
            echo "[$(date)] WARNUNG: Mosquitto-Prozess nicht gefunden"
        fi

        rm -f "${WATCH_DIR}/reload.trigger"
    fi
done
