# Tasks

## 1. Baseline und Backup

- [x] 1.1 ACL-Datei auf `mintfv` mit Zeitstempel sichern und den Referenzzustand von `de-hh-mintfv-uwbox23` aus Broker-Logs und InfluxDB festhalten; Verifikation: Backup-Datei vorhanden und Abfrage zeigt aktuelle Punkte mit `tenant_id=de-hh-mintfv-uwbox23`.
- [x] 1.2 Passwortdatei `mosquitto.passwd` mit Zeitstempel sichern; Verifikation: zweite Backup-Datei vorhanden, ohne dass Hashes ausgegeben werden.
- [x] 1.3 Testidentität `mintfv-smoketest` in ACL und Passwortdatei anlegen, mit `write/read smoketest/mintfv-smoketest/#`, `read umweltbox/de-hh-mintfv-uwbox23/#` und `read $SYS/broker/version`; Verifikation: die ACL zeigt genau diese vier Regeln und keinen Zugriff auf fremde Tenants.
- [x] 1.4 Credentials der Testidentität ausschließlich in `.env` hinterlegen und im Skript aus Umgebungsvariablen lesen; Verifikation: kein Passwort im Repo und keine Passwortausgabe bei der Ausführung.
- [x] 1.5 Skript `tests/mqtt-acl-smoke.sh` implementieren mit statischer ACL-Prüfung, MQTT-Round-Trip im Test-Namespace, Canary-Prüfung auf uwbox23 und InfluxDB-Abfrage; Verifikation: das Skript läuft fehlerfrei und bricht bei einer simulierten Abweichung gegen eine Testkopie mit nicht-Null-Exitcode ab.
- [x] 1.6 Baseline-Smoketest vor jeder Änderung ausführen und protokollieren; Verifikation: Exitcode 0 und abgelegtes Protokoll mit dem Referenzzustand.

## 2. Phase 1: uwbox02 gescopt

- [x] 2.0 Smoketest vor der Änderung ausführen; Verifikation: Exitcode 0 und Protokoll liegt vor.
- [x] 2.1 Die Wildcard-Zeilen `topic write #` und `topic read #` des Benutzers `de-hh-mintfv-uwbox02` durch das exakte uwbox23-Muster mit `umweltbox/de-hh-mintfv-uwbox02/#` und `.../cmnd/#` ersetzen; Verifikation: Diff zeigt nur diese Zeilen und die drei Regeln des Referenzgeräts bleiben unverändert.
- [x] 2.2 Reload der ACL per SIGHUP auslösen; Verifikation: `docker compose logs mosquitto` meldet keinen ACL-Fehler und zeigt weitere Verbindungen.
- [x] 2.3 Datenfluss prüfen; Verifikation: Smoketest nach der Änderung läuft fehlerfrei, InfluxDB liefert weiterhin aktuelle Punkte aus uwbox23-Topics und der uwbox02-Benutzer connectet weiterhin.

## 3. Phase 2: mcp-admin-user entfernen

- [x] 3.0 Smoketest vor der Änderung ausführen; Verifikation: Exitcode 0 und Protokoll liegt vor.
- [x] 3.1 ACL-Block des Benutzers `mcp-admin-user` entfernen; Verifikation: kein Treffer mehr in der ACL, alle anderen Benutzerblöcke unverändert.
- [x] 3.2 Passwort-Eintrag mit `mosquitto_passwd -D` im `mosquitto-admin`-Container löschen; Verifikation: die Benutzerliste (nur Spalte 1) enthält `mcp-admin-user` nicht mehr, ohne Ausgabe von Hashes.
- [x] 3.3 Reload und Auswirkung prüfen; Verifikation: Smoketest nach der Änderung läuft fehlerfrei, Broker-Logs zeigen keine Anmeldung mit dieser Identität und die Punkte in InfluxDB bleiben aktuell.

## 4. Phase 3: nodered-writer auf Lesezugriff reduzieren

- [x] 4.0 Smoketest vor der Änderung ausführen; Verifikation: Exitcode 0 und Protokoll liegt vor.
- [x] 4.1 Regel `readwrite #` durch `read umweltbox/#` ersetzen; Verifikation: Diff zeigt nur diese Zeile und der Flow hat weiterhin keinen `mqtt out`-Knoten.
- [x] 4.2 Reload und Schreibfluss prüfen; Verifikation: Smoketest nach der Änderung läuft fehlerfrei und InfluxDB enthält weiterhin neue Punkte im Measurement `sensors`.

## 5. Phase 4: ACL-Dateirechte korrigieren

- [x] 5.0 Smoketest vor der Änderung ausführen; Verifikation: Exitcode 0 und Protokoll liegt vor.
- [x] 5.1 Modus der ACL-Datei auf `660` setzen, Besitz `2003:2100` beibehalten; Verifikation: `stat -c '%a %u:%g'` liefert `660 2003:2100`.
- [x] 5.2 Schreibfähigkeit der beiden Schreiber prüfen; Verifikation: Smoketest nach der Änderung läuft fehlerfrei und ein kontrollierter Schreibvorgang aus dem Selfservice-Container sowie aus dem Host-Skriptkontext (GID 2100) gelingt ohne Rechtefehler.

## 6. Integrationsprüfung

- [x] 6.1 Gesamtprüfung nach allen Phasen; Verifikation: Abschluss-Smoketest läuft fehlerfrei, die Auswertung der ACL zeigt außer `master-admin` und der gescopten Testidentität keine ungescopte Regel mehr, `de-hh-mintfv-uwbox23` ist unverändert und InfluxDB liefert weiterhin aktuelle Datenpunkte.

## Workflow follow-up

- Change nach Freigabe reviewen und archivieren.
