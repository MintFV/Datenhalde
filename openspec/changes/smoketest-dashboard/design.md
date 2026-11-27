# Design

## Context

Siehe `proposal.md` für die Motivation. Ist-Stand: `tests/mqtt-acl-smoke.sh` läuft per `docker compose exec` gegen mosquitto und InfluxDB, liest `MQTT_SMOKE_USER`/`MQTT_SMOKE_PASS` aus `.env` und gibt nur Konsolenausgabe zurück. Node-RED abonniert ausschließlich `umweltbox/#` und schreibt in das Measurement `sensors`. Grafana lädt Dashboard-Dateien per File-Provider alle 10 Sekunden und nutzt die SQL-Datasource `InfluxDB-MintFV` (UID `PF1260F9C1BE25B8C`) gegen `influxdb:8181`, Datenbank `mintfv`. `influxdb/tokens/admin.token` ist gitignored; ein frischer Checkout kann InfluxDB ohne generierte Tokendatei nicht starten. GitHub-Actions laufen auf `ubuntu-latest`; `docker-compose.ci.yml` enthält nur nginx, und es gibt keine SSH- oder Deploy-Secrets.

## Goals / Non-Goals

**Goals:**

- Smoketest-Ergebnisse inklusive Fehlschlägen dauerhaft in InfluxDB abfragbar machen.
- Ein provisioniertes Dashboard mit aktuellem Status und Verlauf je Prüfung bereitstellen.
- Nach jedem Push auf beliebigem Branch einen isolierten Smoketest auf dem Runner ausführen.
- Keinen neuen Produktionszugriff aus GitHub Actions einführen.

**Non-Goals:**

- Kein periodischer Scheduler; der Smoketest läuft weiterhin bedarfsgesteuert (nach KI-Änderungen sowie vor/nach ACL- und Deploy-Änderungen).
- Kein Schreiben von CI-Ergebnissen in die Produktions-InfluxDB und keine neue öffentliche Restschnittstelle.
- Keine Änderung an Mosquitto-ACL/-Passwortdatei, Node-RED-Flows, nginx, `sensors`, bestehendem Dashboard oder GitHub-Secrets.
- Kein Alerting.

## Decisions

**1. Schreibpfad direkt aus dem Smoketest nach InfluxDB.** Das Skript nutzt `influxdb3 write` innerhalb des InfluxDB-Containers und denselben Admin-Token wie bisher die Canary-Abfrage. Es wird nur das neue Measurement `smoketest_results` beschrieben; Token und Passwörter werden weder geloggt noch in Felder geschrieben. Alternative 1 (Ergebnisse per MQTT an Node-RED) verworfen: Node-RED hört bewusst nur auf `umweltbox/#`, und bei einem MQTT-Fehler könnte das Ergebnis nicht mehr gemeldet werden. Alternative 2 (Grafana-Annotations per API) verworfen: benötigt ein Grafana-Token und liefert kein eigenes, abfragbares Dashboard.

**2. Datenmodell: ein Punkt pro Prüfung plus Gesamtpunkt.** Line Protocol in `mintfv`, Measurement `smoketest_results`, Tag `check` mit den Werten `acl`, `mqtt`, `canary`, `overall`, Felder `ok` (0/1) und `canary_count` nur beim Canary. Bei einem Fehlschlag schreibt `fail()` den Punkt der betroffenen Prüfung und `overall=0`, bevor das Skript mit nicht-Null-Exitcode endet. Alternative 1 (ein Punkt pro Lauf mit mehreren Feldern) verworfen: bei frühem Abbruch fehlen Felder, und die Dashboard-Abfragen werden komplexer. Alternative 2 (eigene Datenbank `smoketest`) verworfen: die vorhandene Grafana-Datasource ist auf `mintfv` festgelegt, eine zweite Datenbank würde eine Datasource oder Cross-Database-SQL erfordern. Das Schreiben ist best-effort und darf den eigentlichen Prüfungsfehler nicht überdecken.

**3. Dashboard als provisionierte Datei.** Neue Datei `grafana/dashboards/mintfv-smoketest.json` mit Titel „mintfv - Smoketest Status" und UID `mintfv-smoketest`. Panels: Stat-Karte für das letzte `overall`, drei Zeitreihen für `ok` je `check`, Tabelle der letzten Läufe mit `canary_count`; alle Queries als SQL mit `$__timeFilter(time)` gegen die vorhandene Datasource. Änderungen erfolgen ausschließlich in der Datei, nicht in der Grafana-UI, weil der File-Provider UI-Änderungen im 10-Sekunden-Takt überschreibt.

**4. Ausführung nach Push: isolierter Stack.** Neue Workflow-Datei `.github/workflows/mqtt-smoke.yml` mit `on: push` ohne Branch-Filter. Der Runner startet mosquitto und InfluxDB aus dem normalen Compose-File mit einem zweiten Override, das gültige Wegwerf-ACL/-Passwortdateien für Mosquitto 2 und eine generierte `influxdb/tokens/admin.token` bereitstellt; `.env` und `.env.smtp.password` erhalten Platzhalter. Danach läuft `tests/mqtt-acl-smoke.sh` gegen diesen Stack. Alternativen SSH auf `mintfv` oder direkter REST-Schreibzugriff auf Produktion sind durch die Betriebsregel ausgeschlossen und würden neue Secrets erfordern.

## Risks / Trade-offs

- [Smoketest schreibt jetzt in Produktions-InfluxDB] → nur in `smoketest_results`, nie in `sensors`; Token-Verarbeitung bleibt unverändert und wird nicht ausgegeben.
- [InfluxDB-Schreiben schlägt fehl] → best-effort, der Fehler wird geloggt, aber der eigentliche Prüfungsfehler und der Exitcode bleiben erhalten; ein erfolgreicher Lauf ohne gespeicherte Ergebnisse ist im Dashboard nicht sichtbar.
- [File-Provider überschreibt UI-Änderungen] → Dashboard nur in der JSON-Datei pflegen.
- [Mosquitto 2 lehnt die eingecheckten ACL-/Passwortdateien ab] → CI nutzt ein Wegwerf-Override; die eingecheckten Dateien bleiben unangetastet.
- [Dashboard zeigt nur bei manuellen Läufen neue Daten] → bewusst akzeptiert, kein Scheduler in diesem Change; im Panel-Titel steht „zuletzt manuell ausgeführt".
- [Generierter Admin-Token im CI-Stack] → zufälliger Wegwerfwert, der mit dem Runner verworfen wird; kein GitHub Secret.

## Migration Plan

1. Specs und Tasks reviewen, danach Skript, Dashboard-Datei und Workflow umsetzen.
2. Lokal gegen einen isolierten Stack verifizieren: erfolgreicher Lauf erzeugt vier Punkte; erzwungenes Scheitern gegen eine ACL-Kopie erzeugt `ok=0` und nicht-Null-Exitcode; Dashboard-Queries liefern die Punkte.
3. Auf `mintfv` die geänderten Dateien deployen, anschließend `./tests/mqtt-acl-smoke.sh` ausführen: `SMOKE_OK`, Punkte in `smoketest_results`, Dashboard per Grafana-API mit UID `mintfv-smoketest` sichtbar.
4. Rolleback: Dateien zurücksetzen; bereits geschriebene Ergebnispunkte bleiben harmlos, weil kein Panel sie als Produktionsdaten interpretiert.

## Open Questions

- Späterer Follow-up, nicht Teil dieses Changes: Smoketest-Ergebnisse aus CI über eine öffentliche Restschnittstelle in das Produktions-Dashboard schreiben. Heute fehlt dafür ein schreibbeschränkter Account (`influxdb3 create token` kennt nur `--admin`). Das erfordert eine eigene Freigabe und einen separaten Change.
