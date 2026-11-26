# Proposal

## Why

Die produktive MQTT-ACL auf `mintfv` enthält vier ungescopte Identitäten: `de-hh-mintfv-uwbox02` darf mit `write #` und `read #` alle Topics lesen und schreiben, `mcp-admin-user` hat `readwrite #`, ohne dass eine Nutzung im Code oder in den Logs der letzten 30 Tage gefunden wurde, und `nodered-writer` hat `readwrite #`, obwohl der Flow nur einen `mqtt in`-Knoten besitzt. Zusätzlich ist die ACL-Datei auf dem Host weltbeschreibbar. Das unterläuft die Mandantentrennung, die für das Projekt zentral ist.

Der Zeitpunkt ist günstig, weil der Datenfluss von `de-hh-mintfv-uwbox23` nachweislich funktioniert und als unveränderliches Referenzmuster dient. Die Härtung soll deshalb schrittweise, mit Backup und nach jeder Phase verifiziert erfolgen, statt den laufenden Betrieb zu riskieren. Dafür wird ein einfacher, wiederholbarer Konfigurations-Smoketest implementiert, der vor und nach jeder Änderung läuft.

## What Changes

- `de-hh-mintfv-uwbox02` erhält exakt dasselbe scoping-Muster wie `de-hh-mintfv-uwbox23`: `write umweltbox/de-hh-mintfv-uwbox02/#`, `read umweltbox/de-hh-mintfv-uwbox02/cmnd/#` und `read $SYS/broker/version`. Die beiden Wildcard-Zeilen werden entfernt.
- `mcp-admin-user` wird aus ACL und Passwortdatei entfernt. Es gibt keinen Code- und Konfigurationsverweis darauf und keine Verbindungen in den vorhandenen Logs.
- `nodered-writer` wird von `readwrite #` auf `read umweltbox/#` reduziert. Der Node-RED-Flow enthält keine `mqtt out`-Knoten.
- Die Datei `mosquitto/config/mosquitto.acl` verliert die weltweiten Schreibrechte. Besitz und Modus werden so gewählt, dass der Selfservice weiterhin schreiben und Mosquitto weiterhin lesen kann.
- Eine gescopte Testidentität `mintfv-smoketest` wird angelegt. Sie darf nur unter `smoketest/mintfv-smoketest/#` schreiben und lesen, nur `umweltbox/de-hh-mintfv-uwbox23/#` und `$SYS/broker/version` lesen und hat keinen Zugriff auf fremde Tenants. Der Test-Topikbereich liegt außerhalb von `umweltbox/#` und erreicht Node-RED daher nicht.
- Ein einfacher Smoketest wird implementiert und vor sowie nach jeder Phase ausgeführt: statische ACL-Prüfung, MQTT-Round-Trip im Test-Namespace, Canary-Lesezugriff auf uwbox23 und InfluxDB-Abfrage. Credentials liegen ausschließlich in `.env` und werden nicht versioniert.
- Alle Schritte erfolgen phasenweise mit ACL-Backup, Reload per SIGHUP und Verifikation über Smoketest, mosquitto-Logs und InfluxDB-Abfragen. `de-hh-mintfv-uwbox23`, der Node-RED-Parser und die Schreibweise des Measurements `sensors` bleiben unverändert.
- Bestehende, korrekt gescopte Tenants behalten ihre Regeln; es gibt keine **BREAKING**-Änderung für funktionierende Geräte.

## Capabilities

### New Capabilities

- `mqtt-access-control`: Regeln für die Vergabe und den Entzug von MQTT-Broker-Berechtigungen, die Mandantenisolation durch Topic-Scoping, das Entfernen ungenutzter Identitäten sowie Reload und wiederholbare Verifikation von ACL-Änderungen durch einen Smoketest.

### Modified Capabilities

(keine – das Projekt hat noch keine Specs)

## Impact

- Produktivsystem `mintfv.peddy.net`: `mosquitto/config/mosquitto.acl` und `mosquitto/config/mosquitto.passwd`, der laufende `mosquitto`-Container sowie der Reload über den Sidecar bzw. `kill -s HUP`.
- Der Selfservice schreibt ACL und Passwortdatei unter `fcntl.flock()` und löst anschließend den Reload aus; diese Fähigkeit muss nach der Rechtekorrektur erhalten bleiben.
- Node-RED liest als `nodered-writer` aus `umweltbox/#` und schreibt per HTTP in InfluxDB, Datenbank `mintfv`, Measurement `sensors`.
- Neues Skript `tests/mqtt-acl-smoke.sh` sowie die nicht versionierten Einträge für Benutzer und Passwort der Testidentität in `.env`.
- Keine Änderung an `docker-compose.yaml`, Images, Ports, am Node-RED-Flow oder am lokalen Branch.
