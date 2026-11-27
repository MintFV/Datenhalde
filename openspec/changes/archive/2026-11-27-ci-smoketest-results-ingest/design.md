# Design

## Context

Siehe `proposal.md` für die Motivation und die Spec-Deltas für das geforderte Verhalten. Ist-Stand: `tests/mqtt-acl-smoke.sh` schreibt Ergebnisse direkt per `influxdb3 write` in `mintfv`/`smoketest_results`; die GitHub-Action führt denselben Test gegen einen Wegwerf-Stack aus. Node-RED abonniert heute ausschließlich `umweltbox/#` (Identität `nodered-writer`, auf `mintfv` nur `read umweltbox/#`) und schreibt über einen HTTP-Request-Node an `http://influxdb:8181/api/v3/write_lp?db=mintfv`. Der Broker ist über nginx auf TLS-Port 8883 öffentlich erreichbar, erlaubt aber keine anonymen Clients. Die gescopte Identität `mintfv-smoketest` darf bereits `write smoketest/mintfv-smoketest/#`. Das Dashboard `mintfv-smoketest` wird per File-Provider geladen. Der archivierte Change hat MQTT damals verworfen, weil Node-RED nur `umweltbox/#` hört und ein MQTT-Fehler die Fehlermeldung selbst blockiert; der aktuelle Change nimmt diesen Pfad bewusst in Kauf und löst die CI-Anlieferung über GitHub-Secrets.

## Goals / Non-Goals

**Goals:**

- Smoketest-Ergebnisse aus manuellen Läufen und aus CI über den bestehenden MQTT-Datenpfad in InfluxDB bringen.
- Keinen neuen HTTP-Endpunkt, keinen Verifier-Dienst und keinen neuen InfluxDB-Token benötigen.
- Herkunft und Laufidentität in den Punkten und im Dashboard sichtbar machen.
- Fehlschläge genauso übermitteln wie Erfolge.

**Non-Goals:**

- Kein SSH und kein Admin-Token in GitHub Actions.
- Kein neues Thema unter `umweltbox/#` und keine Erweiterung der MQTT-Schreibrechte der Testidentität.
- Kein Scheduler, kein Alerting und keine Änderung an `sensors` oder am bestehenden Umweltdashboard.
- Keine Änderung an nginx, InfluxDB-Token oder -Datenbank.

## Decisions

**1. MQTT als einziger Transport für Ergebnisse.** Manuelle Läufe veröffentlichen unter `smoketest/mintfv-smoketest/results/prod`, CI unter `smoketest/mintfv-smoketest/results/ci`. Das bestehende Schreibrecht `write smoketest/mintfv-smoketest/#` der Testidentität deckt beide ab, es braucht kein neues Topic-Recht für den Publisher. Das Payload ist kompakt JSON mit `check`, `ok`, optional `canary_count` und für CI `run_id`, `sha`, `ref`. Die Herkunft wird ausschließlich aus dem Topic-Suffix abgeleitet; ein Absender kann sie nicht im Payload überschreiben. Alternative OIDC-HTTP-Endpunkt verworfen: neuer öffentlicher Endpunkt plus Verifier mit Admin-Token, während MQTT dieselben Daten ohne neue Infrastruktur transportiert. Alternative unautorisiertes Topic verworfen: öffentlich fälschbare Ergebnisse.

**2. Neue GitHub-Secrets für die gescopte Identität.** Der CI-Workflow erhält `MQTT_SMOKE_USER` und `MQTT_SMOKE_PASS` als GitHub-Secrets mit dem Wert der bestehenden, eng gescopten Identität `mintfv-smoketest`. Sie darf nur `smoketest/mintfv-smoketest/#` schreiben und niemals `umweltbox/#`; sie ist kein Admin-Token. Damit wird die bisherige Regel „keine neuen GitHub-Secrets" bewusst für genau diese beiden Secrets durchbrochen (vom User freigegeben). Die dauerhafte Dokumentation dieser Ausnahme in `AGENTS.md` ist zunächst zurückgestellt. Alternative OIDC-Brücke verworfen: kein Gewinn ohne Endpunkt.

**3. ACL nur lesend für Node-RED erweitern.** `nodered-writer` erhält zusätzlich `topic read smoketest/mintfv-smoketest/results/#` und weiterhin keine Schreibrechte. Die Änderung läuft über den Selfservice-MQTT-Pfad mit `flock` und Reload-Trigger, nicht durch direktes Editieren der eingecheckten Dateien (diese sind für Mosquitto 2 ungültig). Vorher Backup, danach SIGHUP-Reload und `./tests/mqtt-acl-smoke.sh` → `SMOKE_OK`. Damit bleibt die Spec-Regel „nur Lesezugriff" inhaltlich erhalten, wird aber um das Ergebnis-Topic erweitert.

**4. Node-RED verarbeitet die Nachrichten.** Ein zweiter `mqtt in`-Knoten abonniert `smoketest/mintfv-smoketest/results/#` über denselben Broker. Ein Function-Node validiert `check`/`ok`/`canary_count`, lehnt unbekannte Werte ab und baut Line Protocol für `smoketest_results` mit `source`, `run_id`, `sha` und `ref`. Der vorhandene HTTP-Request-Node schreibt in dieselbe InfluxDB; der Admin-Token bleibt auf `mintfv`. Änderungen erfolgen in `nodered/data/flows.json`, nicht in der UI. Alternative direkter InfluxDB-Schreibzugriff aus Skript/Workflow verworfen: genau den bestehenden Node-RED-Pfad nutzen, der auch die Sensordaten schreibt.

**5. Skript und Workflow publizieren, statt direkt zu schreiben.** `tests/mqtt-acl-smoke.sh` ersetzt seinen `influxdb3 write`-Pfad durch einen MQTT-Publish: auf `mintfv` mit den lokalen `.env`-Credentials nach `.../results/prod`, im CI-Stack mit den GitHub-Secrets direkt an `mintfv.peddy.net:8883` nach `.../results/ci`. `fail()` veröffentlicht `ok=0` für die Prüfung und `overall`, bevor das Skript beendet. Der Publish ist best-effort und darf den eigentlichen Prüfungsfehler nicht überdecken; ein fehlgeschlagener Publish wird im Log gemeldet. Der lokale MQTT-Round-Trip des Smoketests bleibt davon unberührt und läuft wie heute gegen den jeweiligen Broker.

**6. Dashboard-Trennung bleibt bestehen.** Die `source`-Variable (`prod`|`ci`, Default `prod`) und das CI-Panel aus dem bisherigen Entwurf werden unverändert übernommen; `source` kommt jetzt aus dem Topic-Suffix statt aus einem HTTP-Payload. Damit ist auch weiterhin erkennbar, dass ein CI-Punkt den isolierten Runner und nicht die Produktion beschreibt.

## Risks / Trade-offs

- [MQTT ist Transport und Prüfling zugleich] → Bei Broker-Ausfall kann das Ergebnis nicht geliefert werden; der CI-Workflow protokolliert den Fehler trotzdem und endet mit nicht-Null-Exitcode. Bewusst akzeptiert.
- [Node-RED in der kritischen Kette] → Fällt der Flow aus, fehlen Dashboard-Punkte; der bestehende Healthcheck und das Flow-Deployment werden in der Abnahme geprüft.
- [GitHub-Secrets] → nur die gescopte Identität, kein Admin-Token, kein SSH; Secrets sind widerrufbar rotierbar. Die Regeländerung ist nur für diesen Change freigegeben und noch nicht dauerhaft dokumentiert.
- [Jemand mit dem Secret kann Ergebnisse fälschen] → Identität ist bereits auf das Smoketest-Topic beschränkt; weiterer Schutz ist nicht vorgesehen.
- [ACL-Änderung kann bestehende Rechte brechen] → Backup, Selfservice-Pfad, Reload und Abschluss-Smoke; `nodered-writer` behält `read umweltbox/#`.
- [Eingecheckte ACL-/Passwortdateien sind für Mosquitto 2 ungültig] → keine Host-Änderung an diesen Dateien, sondern Produktionsänderung über den Selfservice-Weg.
- [Tag-Kardinalität durch `run_id`/`sha`] → bewusst akzeptiert; keine Retention in diesem Change.

## Migration Plan

1. Specs und Tasks reviewen; GitHub-Secrets für `mintfv-smoketest` anlegen und auf den CI-Runner wirken lassen.
2. ACL über Selfservice um `read smoketest/mintfv-smoketest/results/#` für `nodered-writer` erweitern; Backup, Reload und Smoke → `SMOKE_OK`.
3. Node-RED-Flow um Abonnement, Validierung und Line-Protocol-Mapping ergänzen; lokal gegen einen Test-Broker prüfen, dass gültige Nachrichten Punkte erzeugen und ungültige verworfen werden.
4. Skript und Workflow auf MQTT-Publish umstellen; manuellen Lauf und erzwungenen CI-Fehlschlag testen (jeweils vier Punkte bzw. `ok=0` für Prüfung und `overall`).
5. Dashboard um `source`-Variable und CI-Panel ergänzen; Grafana-API liefert 200 für UID `mintfv-smoketest`.
6. Produktionsabnahme: echter Push erzeugt Punkte mit `source=ci`, `run_id`, `sha`, `ref`; Abschluss `./tests/mqtt-acl-smoke.sh` → `SMOKE_OK`.
7. Rollback: Flow, Skript, Workflow und Dashboard zurücksetzen, ACL-Regel entfernen, GitHub-Secrets löschen. Bereits geschriebene Punkte bleiben harmlos, weil das Dashboard standardmäßig `source=prod` filtert.

## Open Questions

- Die dauerhafte Dokumentation der Secret-Ausnahme in `AGENTS.md` ist vom User bewusst zurückgestellt und wird in einem separaten Schritt entschieden.
- Langfristige Aufbewahrung bzw. Begrenzung der Tag-Kardinalität (`run_id`, `sha`) wird bei Bedarf in einem separaten Change entschieden.
