# selfservice-deployment Specification

## Purpose

Diese Capability beschreibt, wie der produktive Selfservice auf den Stand des Repositories gebracht wird, ohne die direkt auf dem Host gehärtete Konfiguration zu verlieren, und wie ein solcher Deploy verifiziert und bei Bedarf zurückgenommen wird.

## Requirements

### Requirement: Produktiver Code entspricht dem Repository-Stand

Nach dem Deploy SHALL der auf `mintfv` ausgelieferte Selfservice die Funktionen des deployed Commits enthalten. Insbesondere SHALL `/selfservice/tenant/uebersicht` nicht mehr mit 404 antworten.

#### Scenario: Tenant-Route ist vorhanden

- **WHEN** nach dem Deploy `/selfservice/tenant/uebersicht` abgefragt wird
- **THEN** antwortet der Server nicht mit 404, sondern mit der Login-Weiterleitung oder der Tenant-Übersicht

#### Scenario: Commit-Stand stimmt überein

- **WHEN** der Git-Stand auf `mintfv` mit dem lokalen Branch `refactorPED` verglichen wird
- **THEN** zeigen beide denselben Commit

### Requirement: Live-Härtung bleibt erhalten

Ein Deploy SHALL die gitignorierten Dateien `mosquitto/config/mosquitto.acl`, `mosquitto/config/mosquitto.passwd` und `mosquitto/config/backups/` nicht überschreiben oder löschen. Die ACL SHALL weiterhin Modus `660` und die gescopten Regeln enthalten.

#### Scenario: ACL nach dem Deploy

- **WHEN** nach dem Deploy die ACL-Datei und der Smoketest geprüft werden
- **THEN** ist der Modus `660`, enthält keine ungescopte Regel außer `master-admin`, und der Smoketest meldet `SMOKE_OK`

#### Scenario: Backups bleiben vorhanden

- **WHEN** nach dem Deploy das Backup-Verzeichnis geprüft wird
- **THEN** sind die Sicherungen vom 2026-11-26 weiterhin vorhanden und nicht verändert

### Requirement: Deploy ist verifizierbar und rückholbar

Nach jedem Deploy SHALL der Datenfluss geprüft werden. Bei einer Abweichung SHALL ein Rollback auf den vorherigen Commit möglich sein, ohne die Datenbank zu verändern.

#### Scenario: InfluxDB schreibt weiter

- **WHEN** nach dem Deploy die letzten Minuten von `sensors` abgefragt werden
- **THEN** enthält die Tabelle aktuelle Punkte von `de-hh-mintfv-uwbox23`

#### Scenario: Rollback bei Abweichung

- **WHEN** eine Verifikation nach dem Deploy fehlschlägt
- **THEN** kann der Server auf `e1b95a3` zurückgesetzt und das Image neu gebaut werden, während die Datenbank auf `001_initial` bleibt
