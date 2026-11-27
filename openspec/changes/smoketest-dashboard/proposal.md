# Proposal

## Why

Der MQTT-ACL-Smoketest liefert heute nur Konsolenausgabe (`PASS`, `FAIL`, `SMOKE_OK`) und ist damit nach einem Lauf nicht mehr nachvollziehbar. Gerade nach Änderungen durch KI-Agenten und nach ACL-/Deploy-Änderungen fehlt ein dauerhaft sichtbarer Nachweis, ob die gescopte Testidentität, der Round-Trip und der InfluxDB-Canary funktioniert haben. Grafana zeigt bereits alle übrigen Betriebsdaten, aber keine Smoketest-Ergebnisse.

## What Changes

- `tests/mqtt-acl-smoke.sh` schreibt das Ergebnis jeder Prüfung (`acl`, `mqtt`, `canary`) sowie ein Gesamtergebnis (`overall`) als Punkt in InfluxDB. Fehlgeschlagene Läufe werden mit `ok=0` gespeichert, bevor das Skript mit nicht-Null-Exitcode endet.
- Neues provisioningiertes Dashboard `grafana/dashboards/mintfv-smoketest.json`: Stat-Karte für den letzten Lauf, Zeitreihen je Prüfung und eine Tabelle der letzten Läufe mit Canary-Punktzahl. Die Queries bleiben SQL auf der vorhandenen InfluxDB-3-Core-Datasource.
- Neue GitHub-Action mit `on: push` ohne Branch-Filter. Sie startet auf dem Runner einen isolierten Stack aus mosquitto und InfluxDB mit Wegwerf-ACL/-Passwort und generiertem Admin-Token und führt dort den Smoketest aus. Damit wird nach jedem Push geprüft, dass das Smoketest-Werkzeug weiterhin funktioniert. Es gibt **keinen** SSH-Zugriff aus GitHub Actions auf `mintfv`, keine Produktionszugriffe und keine neuen Secrets.
- `AGENTS.md` erhält zwei Betriebsregeln: GitHub Actions greifen niemals per SSH auf `mintfv` zu, sondern höchstens über öffentliche Restschnittstellen (neue Endpunkte nur nach Rückfrage); nach KI-Änderungen läuft der Smoketest einmal.
- **Später (nicht Teil dieses Changes):** Die Ergebnisse aus der GitHub-Action auch in das Produktions-Dashboard zu schreiben. Über eine öffentliche REST-Schnittstelle ist das heute nicht sauber möglich, weil `influxdb3 create token` nur `--admin` kennt und es damit keinen schreibbeschränkten Account für CI gibt. Der Follow-up wird in `design.md` festgehalten und benötigt vor einer Umsetzung eine eigene Freigabe.

## Capabilities

### New Capabilities

- keine

### Modified Capabilities

- `mqtt-access-control`: Der Smoketest SHALL seine Ergebnisse einschließlich Fehlschlägen in InfluxDB speichern; die Ergebnisse entstehen dabei weiterhin nicht über MQTT/Node-RED.
- `grafana-dashboards`: Ein provisioningiertes Dashboard SHALL die Smoketest-Ergebnisse als Status und Verlauf je Prüfung anzeigen.

## Impact

- Geändert: `tests/mqtt-acl-smoke.sh`, `AGENTS.md`, `openspec/specs/mqtt-access-control/spec.md`, `openspec/specs/grafana-dashboards/spec.md`.
- Neu: `grafana/dashboards/mintfv-smoketest.json`, `.github/workflows/mqtt-smoke.yml`, Change-Artefakte unter `openspec/changes/smoketest-dashboard/`.
- InfluxDB: neues Measurement `smoketest_results` in der bestehenden Datenbank `mintfv`; kein neues Token, keine Änderung an `sensors`.
- Unverändert: Mosquitto-ACL/-Passwortdatei, Node-RED-Flows, bestehendes Dashboard `mintfv-dashboard.json`, nginx-Konfiguration, GitHub-Secrets und der Produktionsstack.
