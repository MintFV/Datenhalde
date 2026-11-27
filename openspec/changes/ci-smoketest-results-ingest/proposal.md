# Proposal

## Why

Der GitHub-Action-Smoketest läuft bei jedem Push gegen einen isolierten Wegwerf-Stack; seine Ergebnisse bleiben auf dem Runner und sind im Produktions-Grafana unsichtbar. Gleichzeitig sollen Ergebnisse aus manuellen Läufen und aus CI im selben Dashboard nachvollziehbar sein, ohne dass CI-Ergebnisse als Produktionszustand gelesen werden.

## What Changes

- Smoketest-Ergebnisse werden künftig über MQTT angeliefert: Das Skript bzw. der CI-Workflow veröffentlicht sie unter `smoketest/mintfv-smoketest/results/{prod|ci}`. Node-RED abonniert dieses Topic und schreibt die Punkte in `mintfv`/`smoketest_results`. Es entsteht **kein** neuer HTTP-Endpunkt, kein Verifier-Dienst und kein neuer InfluxDB-Token.
- **BREAKING der bisherigen Betriebsregel:** Die GitHub-Action verwendet die bereits gescopte Identität `mintfv-smoketest` aus der Produktion als GitHub-Secrets. Sie darf nur unter `smoketest/mintfv-smoketest/#` schreiben und nicht unter `umweltbox/#`. SSH und ein Admin-Token in CI bleiben ausgeschlossen.
- `nodered-writer` erhält zusätzlich `topic read smoketest/mintfv-smoketest/results/#` und bleibt damit weiterhin rein lesend; die ACL-Änderung erfolgt über den Selfservice-Weg mit Backup und anschließendem Smoketest.
- Jeder Punkt trägt `source=prod` oder `source=ci`; CI-Punkte zusätzlich `run_id`, `sha` und `ref`. Das Dashboard `mintfv-smoketest` filtert über eine `source`-Variable und zeigt CI-Läufe in einem eigenen Panel.
- Die bisherige direkte InfluxDB-Schreibroute des Skripts entfällt zugunsten des MQTT-Pfads; das Gros der Datenhaltung bleibt bei Node-RED/InfluxDB wie bei den Sensordaten.

## Capabilities

### New Capabilities

- `smoketest-result-publishing`: Veröffentlichung und Verarbeitung von Smoketest-Ergebnissen über MQTT, inklusive Herkunft und Laufidentität.

### Modified Capabilities

- `mqtt-access-control`: Die Testidentität veröffentlicht Ergebnisse via MQTT; `nodered-writer` darf das Ergebnis-Topic lesen; Ergebnispunkte entstehen über Node-RED statt durch direkten InfluxDB-Schreibzugriff des Skripts.
- `grafana-dashboards`: Das Smoketest-Dashboard trennt manuelle und CI-Ergebnisse über `source`.

## Impact

- Geändert: `tests/mqtt-acl-smoke.sh`, `.github/workflows/mqtt-smoke.yml`, `nodered/data/flows.json`, Produktions-ACL (über Selfservice), `grafana/dashboards/mintfv-smoketest.json`, README-Dokumentation.
- Neu: zwei GitHub-Secrets für die gescopte Smoke-Identität; keine neuen Container, Endpunkte oder Ports.
- InfluxDB: zusätzliche Tags im bestehenden Measurement `smoketest_results`; keine neue Datenbank, kein neues Token, `sensors` unverändert.
- Produktion: ACL- und Flow-Änderung, danach `./tests/mqtt-acl-smoke.sh` → `SMOKE_OK`. Nginx bleibt unverändert.
- Unverändert: SSH-Zugriff, Admin-Token-Verteilung, MQTT-Schreibrechte der Testidentität, Bestandsdaten in `sensors`, bestehendes Dashboard `mintfv-dashboard.json`.
