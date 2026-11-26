# Design

## Context

Siehe `proposal.md` für die Motivation. Gemessener Stand: lokaler Branch `openspec` bei `5f1e314`, 17 Commits vor `e1b95a3`; der Server-Checkout `/home/peddy/mintfv` läuft auf `refactorPED`@`e1b95a3`. Die uncommitteten Server-Dateien `style.css` und `mintfv-dashboard.json` sind **byte-identisch** zu den lokalen Versionen (MD5 `59169bdf…` bzw. `efcecd65…`), der Datenbankstand ist `001_initial (head)`. Das untracked `tests/mqtt-acl-smoke.sh` unterscheidet sich nur in Einrückung (Tabs vs. Spaces), nicht in der Funktion. `mosquitto/config/backups/` ist ein bewusstes Live-Artefakt.

## Goals / Non-Goals

**Goals:**
- Den produktiven Selfservice auf den Repository-Stand bringen, damit Tenant-/Device-Verwaltung und rollengerechte ACLs aktiv sind.
- Die live gehärtete Broker-Konfiguration und die Backups unverändert lassen.
- Den Deploy mit denselben Prüfmitteln verifizieren, die schon im ACL-Change etabliert wurden.

**Non-Goals:**
- Kein `git push` durch den Agenten – der Benutzer pusht `refactorPED` selbst.
- Keine Änderung an `.env`, Tokens, `mosquitto.acl`, `mosquitto.passwd`, Compose-Datei, Ports oder Datenbankschema.
- Kein Neustart anderer Dienste als `selfservice` und `mosquitto-reload`.

## Decisions

**1. Fast-Forward statt Cherry-Pick.**
`refactorPED` zeigt lokal noch auf `c2552db`, `openspec` ist ein direkter Nachfahre. Ein `git merge --ff-only` ist konfliktfrei und übernimmt alle 17 Commits. Alternative: nur die vier Funktions-Commits cherry-picken – verworfen, weil danach Doku und Code erneut auseinanderlaufen würden.

**2. Push durch den Benutzer, Fetch auf dem Server.**
Der Agent pusht nie. Der Benutzer pusht den lokalen `refactorPED`; auf `mintfv` genügt `git fetch origin` und `git merge --ff-only origin/refactorPED`. Alternative: Bundle/Patch per SSH übertragen – verworfen, weil umständlicher und fehleranfälliger.

**3. Uncommittete Server-Dateien vor dem Merge abgleichen.**
`style.css` und das Dashboard sind bereits identisch mit Ziel-Commit; nach dem Fast-Forward werden sie automatisch „clean". Die untracked Smoke-Skript-Kopie ist funktional identisch, würde einen Merge aber blockieren. Sie wird nach einem `diff -w`-Abgleich entfernt und durch die versionierte Datei ersetzt. `mosquitto/config/backups/` bleibt unangetastet.

**4. Rebuild nur der betroffenen Container.**
`docker compose build selfservice mosquitto-reload` gefolgt von `docker compose up -d selfservice mosquitto-reload` (Reihenfolge aus `selfservice/README.md:173-174`). Das `entrypoint.sh` führt `flask db upgrade` aus; da bereits `001_initial (head)` aktiv ist, ist keine Migration nötig.

**5. Verifikation vor Freigabe, Rollback vorbereitet.**
Geprüft werden Git-Stand, Tenant-Route `/selfservice/tenant/uebersicht` (nicht mehr 404), Smoketest, ACL-Modus/Regeln, Backups und InfluxDB-Punkte. Bei Abweichung: Server auf `e1b95a3` zurücksetzen, Image neu bauen, erneut verifizieren. Ein `git reset --hard` ist destruktiv und benötigt eine separate, explizite Freigabe.

## Risks / Trade-offs

- [nginx cached die alte Container-IP und liefert 502] → nach dem Recreate `docker compose kill -s HUP nginx`, danach Route prüfen.
- [Kurze Unterbrechung des Selfservice beim Neustart] → nur `selfservice`/`mosquitto-reload` neu starten, nach dem Start Healthcheck und Route prüfen.
- [Push vergessen] → der Server bleibt auf altem Stand; Verifikation „Commit-Stand stimmt überein" schlägt fehl und stoppt den Deploy vor dem Rebuild.
- [Untracked Smoke-Skript blockiert den Merge] → vorher `diff -w` prüfen, dann Kopie entfernen; die versionierte Datei ist funktional gleich.
- [ACL oder Passwort werden überschrieben] → beide sind gitignoriert und nicht Teil des Merges; trotzdem nach dem Deploy explizit prüfen.
- [Rollback wird nötig] → Datenbank bleibt auf `001_initial`, es gibt keine Schemaänderung; Rollback betrifft nur Git-Stand und Image.

## Migration Plan

1. Lokal `refactorPED` auf `openspec` fast-forwarden; Benutzer pusht `refactorPED`.
2. Auf `mintfv`: `git fetch origin`, Smoke-Skript-Kopie nach `diff -w` entfernen, `git merge --ff-only origin/refactorPED`.
3. `docker compose build selfservice mosquitto-reload` und `docker compose up -d selfservice mosquitto-reload`.
4. Verifikation: `git log -1`, Tenant-Route, `./tests/mqtt-acl-smoke.sh`, `stat`/`grep` der ACL, Backup-Dateien, InfluxDB-Abfrage.
5. Rollback (nur bei Abweichung, mit separater Freigabe): `git reset --hard e1b95a3`, Image neu bauen, Verifikation wiederholen.
