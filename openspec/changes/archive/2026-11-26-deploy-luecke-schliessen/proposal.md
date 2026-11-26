# Proposal

## Why

Auf `mintfv` läuft der Selfservice noch auf Commit `e1b95a3`, während der lokale Branch `openspec` 17 Commits voraus ist. Davon enthalten vier echte Funktionalität (Tenant-/Device-Verwaltung, rollengerechte MQTT-ACLs, CSS/A11y, Type-Stubs). Die Route `/selfservice/tenant/uebersicht` liefert produktiv deshalb 404, und die ACLs werden weiterhin manuell gepflegt. Einige Live-Änderungen (CSS, repariertes Dashboard, Smoketest, Backups) wurden direkt auf dem Host gemacht und sind im Git-Stand des Servers nicht enthalten.

## What Changes

- Den lokalen Branch `openspec` fast-forward auf `refactorPED` mergen. Den Push auf `origin` macht **der Benutzer** (Agenten pushen nie); danach holt der Server `origin/refactorPED` und mergt per `--ff-only`.
- Die uncommitteten Server-Dateien abgleichen: `style.css` und `mintfv-dashboard.json` sind byte-identisch zu den lokalen Versionen und können durch die committeten Fassungen ersetzt werden. `mosquitto/config/backups/` und `tests/mqtt-acl-smoke.sh` bleiben als Live-Artefakte erhalten (Erstere gitignoriert, Letztere nach dem Merge versioniert).
- Das `selfservice`-Image (und `mosquitto-reload`) neu bauen und nur diese Container neu starten. `entrypoint.sh` führt `flask db upgrade` aus; die Datenbank ist bereits auf `001_initial (head)`, es gibt also keine neue Migration.
- Nach dem Deploy verifizieren: Tenant-Routen erreichbar, Smoketest `SMOKE_OK`, `mosquitto.acl` weiterhin Modus `660` mit gescopten Regeln, InfluxDB liefert weiterhin aktuelle Punkte, kein Verlust der Live-Backups.
- Rollback-Path: Server-Checkout auf `e1b95a3` zurücksetzen, Image erneut bauen, Verifikation wiederholen. Die Datenbank unverändert lassen.
- Keine Änderung an `.env`, Tokens, `mosquitto.acl`/`.passwd`, Compose-Datei oder Ports.

## Capabilities

### New Capabilities

- `selfservice-deployment`: Anforderungen daran, dass der produktive Selfservice-Code dem Repository-Stand entspricht und ein Deploy ohne Verlust der live gehärteten Konfiguration verifizierbar und rückholbar ist.

### Modified Capabilities

(keine)

## Impact

- Lokal: Branch `refactorPED` zeigt nach dem Merge auf `5f1e314`; Push erfolgt durch den Benutzer.
- Produktiv: Git-Checkout `/home/peddy/mintfv`, Container `selfservice` und `mosquitto-reload`, kurzer Neustart dieser Dienste.
- Die Datenbank bleibt auf `001_initial`; keine Schemaänderung, kein Datenverlust erwartet.
