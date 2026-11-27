# Tasks

## 1. Ergebnisschreiben im Smoketest

- [x] 1.1 Helper zum Schreiben von Ergebnispunkten in `tests/mqtt-acl-smoke.sh` ergänzen: `influxdb3 write` in Datenbank `mintfv`, Measurement `smoketest_results`, Tag `check`, Felder `ok` und optional `canary_count`; Token wie bisher aus `/var/lib/influxdb3/tokens/admin.token` lesen, nie ausgeben; Verifikation: `bash -n tests/mqtt-acl-smoke.sh` ist sauber und ein Lauf gegen den isolierten Stack erzeugt Punkte im neuen Measurement.
- [x] 1.2 `fail()` so umbauen, dass vor dem Exit `ok=0` für die fehlgeschlagene Prüfung und `overall=0` geschrieben werden; das Schreiben ist best-effort und verändert weder Fehlermeldung noch Exitcode; Verifikation: Lauf mit manipulierter ACL-Kopie via `ACL_FILE` endet nicht-Null, InfluxDB enthält `ok=0` für `acl` und `overall`, und die Ausgabe enthält `FAIL:`.
- [x] 1.3 Erfolgspfad ergänzen: je Prüfung `ok=1`, Canary-Zähler in `canary_count`, am Ende `overall=1`; `SMOKE_OK` bleibt unverändert; Verifikation: erfolgreicher Lauf meldet `SMOKE_OK`, und eine SQL-Abfrage auf `smoketest_results` liefert vier Punkte mit `ok=1`.
- [x] 1.4 Datenmodell in `influxdb/README.md` dokumentieren (Measurement `smoketest_results`, Tag `check`, Felder, kein Token in Feldern); Verifikation: README enthält das Measurement und einen lesbaren Beispiel-Query, aber keine Secrets.

## 2. Dashboard

- [x] 2.1 `grafana/dashboards/mintfv-smoketest.json` anlegen mit nicht-leerem Titel „mintfv - Smoketest Status", stabiler UID `mintfv-smoketest`, Datasource-UID `PF1260F9C1BE25B8C` sowie Stat-Karte für `overall`, drei Zeitreihen für `ok` je `check` und Tabelle mit `canary_count`; alle Queries als SQL mit `$__timeFilter(time)`; Verifikation: `python3 -m json.tool` akzeptiert die Datei, `grep` findet kein `queryType: flux` und kein `from(bucket:`.
- [x] 2.2 Provisioning und Panels verifizieren: Dashboard wird geladen, Grafana-API liefert HTTP 200 für `api/dashboards/uid/mintfv-smoketest`, und die Panel-Queries geben vorhandene Punkte aus `smoketest_results` zurück; Verifikation: API-Antwort enthält Titel und UID, keine Provisionierungsfehler im Grafana-Log.
- [x] 2.3 `grafana/README.md` um das neue Dashboard ergänzen (Datei, UID, Zweck, Hinweis dass neue Daten nur nach einem Lauf entstehen); Verifikation: README nennt Dateiname und UID.

## 3. GitHub Action

- [x] 3.1 `.github/workflows/mqtt-smoke.yml` mit `on: push` ohne Branch-Filter anlegen; Schritte für Checkout, Platzhalter `.env`/`.env.smtp.password`, Compose-Override mit gültigen Wegwerf-ACL/-Passwortdateien und generierter `influxdb/tokens/admin.token`, Start von mosquitto und InfluxDB, Ausführung von `tests/mqtt-acl-smoke.sh`, Cleanup mit `if: always()`; Verifikation: YAML-Parser akzeptiert die Datei, `git diff --check` ist sauber, die Datei enthält weder SSH noch `secrets.*`.
- [x] 3.2 Workflow-Verhalten prüfen: der Smoke Test läuft ausschließlich gegen den lokalen Runner-Stack und meldet `SMOKE_OK`; Verifikation: Log enthält `SMOKE_OK`, keine Verbindung zu `mintfv`, keine neuen Repository-Secrets nötig.
- [x] 3.3 `.github/README-CI.md` um den neuen Workflow ergänzen (Trigger bei jedem Push, isolierter Stack, kein Prod-Zugriff, keine Secrets); Verifikation: README beschreibt Trigger und Grenzen.

## 4. Integration und Abnahme

- [x] 4.1 Gesamtprüfung lokal: erfolgreicher und erzwungen fehlgeschlagener Lauf, vier Punkte in InfluxDB, Dashboard per API, Workflow-YAML gültig; Verifikation: alle Prüfungen aus 1–3 bestehen.
- [x] 4.2 Produktiv-abnahme nach Deploy durch den Betreiber: geänderte Dateien auf `mintfv` ausrollen, `./tests/mqtt-acl-smoke.sh` meldet `SMOKE_OK`, SQL-Abfrage liefert aktuelle Punkte aus `smoketest_results`, Grafana-API liefert UID `mintfv-smoketest`; Verifikation: alle drei Nachweise vorhanden, bestehendes Dashboard und `sensors` unverändert.

## Workflow follow-up

- Change nach Review archivieren und die Specs aktualisieren.
- Späterer separater Change: Smoketest-Ergebnisse aus CI über eine öffentliche Restschnittstelle mit schreibbeschränktem Konto ins Produktions-Dashboard schreiben (siehe `design.md`, Open Questions); Umsetzung nur nach ausdrücklicher Freigabe.
