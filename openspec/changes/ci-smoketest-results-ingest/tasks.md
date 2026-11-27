# Tasks

## 1. Secrets und Freigaben

- [x] 1.1 Die zwei GitHub-Secrets `MQTT_SMOKE_USER` und `MQTT_SMOKE_PASS` mit der gescopten Identität `mintfv-smoketest` anlegen — Verifikation: ein Test-Publish über `mintfv.peddy.net:8883` gelingt unter `smoketest/mintfv-smoketest/#` und wird unter `umweltbox/#` verweigert
- [ ] 1.2 Sicherstellen, dass keine Admin-Token- oder SSH-Zugangsdaten in den Secrets oder im Workflow liegen — Verifikation: Secret-Werte und Workflow-Text enthalten nur die Smoke-Identität, keinen Token und keinen SSH-Login

## 2. MQTT-ACL

- [x] 2.1 Vor der Änderung eine wiederherstellbare ACL-Kopie anlegen und `nodered-writer` über den Selfservice-Weg um `read smoketest/mintfv-smoketest/results/#` erweitern — Verifikation: `mosquitto.acl` zeigt genau diese zusätzliche read-Regel, keine write-Regel, und das Backup liegt vor
- [x] 2.2 Broker-Reload auslösen und Smoketest ausführen — Verifikation: `./tests/mqtt-acl-smoke.sh` gibt `SMOKE_OK` aus, die uwbox23-Daten bleiben unverändert und Node-RED kann das Ergebnis-Topic abonnieren
- [x] 2.3 Die eingecheckten ACL-/Passwortdateien unverändert lassen — Verifikation: `git status` zeigt keine Änderung an `mosquitto/config/mosquitto.acl` oder `mosquitto.passwd`

## 3. Node-RED-Verarbeitung

- [x] 3.1 Zweiten `mqtt in`-Knoten auf `smoketest/mintfv-smoketest/results/#` sowie Function-Node für Validierung und Line-Protocol-Mapping ergänzen — Verifikation: eine Testnachricht erzeugt einen Punkt in `smoketest_results` mit `source` aus dem Topic
- [x] 3.2 `run_id`, `sha` und `ref` aus der Nachricht in Tags übernehmen und unbekannte `check`-Werte oder unzulässiges `ok` verwerfen — Verifikation: gültige Nachrichten landen mit allen Tags in InfluxDB, ungültige erzeugen keine Punkte
- [x] 3.3 Vorhandenen HTTP-Write-Node weiterverwenden und den Flow ausrollen — Verifikation: Node-RED ist healthy, `sensors` bleibt unverändert und die Dokumentation in `nodered/README.md` beschreibt das neue Abonnement

## 4. Smoketest-Skript

- [x] 4.1 Direkten InfluxDB-Schreibzugriff durch MQTT-Publish nach `.../results/prod` ersetzen — Verifikation: lokaler Lauf endet mit `SMOKE_OK` und erzeugt vier Punkte mit `source=prod`
- [x] 4.2 `fail()` so anpassen, dass `ok=0` für die Prüfung und `overall` veröffentlicht wird — Verifikation: erzwungener Fehlschlag erzeugt die beiden `ok=0`-Punkte und einen von Null verschiedenen Exitcode
- [x] 4.3 Sicherstellen, dass Nachrichten und Logs keine Credentials oder Tokens enthalten — Verifikation: Suche in Skript und ausgegebenen Nachrichten nach Passwörtern und `apiv3_`/`INFLUX`-Token bleibt ohne Treffer

## 5. GitHub-Workflow

- [x] 5.1 Workflow nutzt die Secrets und publiziert über TLS auf Port 8883 nach `.../results/ci`, mit `run_id`, `sha` und `ref` aus der GitHub-Umgebung — Verifikation: ein Push auf einen Testbranch erzeugt Punkte mit `source=ci` und den drei Tags in der Produktions-InfluxDB
- [x] 5.2 Publish auch bei fehlgeschlagener Prüfung ausführen — Verifikation: erzwungener Fehlschlag liefert `ok=0` für Prüfung und `overall` an und der Workflow endet mit Fehler
- [x] 5.3 Kein SSH, kein Admin-Token und kein `secrets.`-Verweis auf InfluxDB im Workflow — Verifikation: Durchsuche von `.github/workflows/mqtt-smoke.yml` zeigt ausschließlich die beiden MQTT-Secrets

## 6. Dashboard

- [x] 6.1 Template-Variable `source` (`prod`|`ci`, Default `prod`) und Filter in den vier bestehenden Panels ergänzen — Verifikation: JSON ist valide, UID bleibt `mintfv-smoketest`, alle Queries sind SQL
- [x] 6.2 Stat-Titel mit Herkunft versehen und CI-Tabelle mit `run_id`, `sha`, `ok` hinzufügen — Verifikation: Grafana-API liefert 200 für die UID; mit CI-Punkten zeigt das CI-Panel die Läufe bei unverändertem Default `prod`
- [x] 6.3 `grafana/README.md` und `influxdb/README.md` um den MQTT-Ergebnispfad und die Herkunftstags ergänzen — Verifikation: dokumentierte Abfragen liefern die erwarteten Spalten

## 7. Produktionsabnahme und Rollback

- [ ] 7.1 Echten Push gegen Produktion ausführen und die angekommenen Punkte prüfen — Verifikation: InfluxDB enthält `source=ci`-Punkte mit `run_id`, `sha`, `ref`; das Dashboard zeigt sie nur im CI-Panel
- [ ] 7.2 Abschluss-Smoketest auf `mintfv` ausführen — Verifikation: `./tests/mqtt-acl-smoke.sh` gibt `SMOKE_OK` aus; ACL- und Passwortdateien sowie `sensors` sind unverändert
- [ ] 7.3 Rollback-Schritte prüfen (Flow, Skript, Workflow, Dashboard zurücksetzen, ACL-Regel entfernen, Secrets löschen) — Verifikation: nach dem Rollback werden keine neuen Ergebnispunkte mehr geschrieben und die gelöschten Secrets sind im Workflow unwirksam

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
