# Tasks

## 1. Lokalen Stand vorbereiten und veröffentlichen

- [x] 1.1 `refactorPED` lokal per `git merge --ff-only openspec` auf den aktuellen HEAD bringen; Verifikation: `git rev-parse refactorPED` und `git rev-parse openspec` sind identisch und `git log --oneline e1b95a3..refactorPED` zeigt 17 Commits.
- [ ] 1.2 Den Push von `refactorPED` durch den Benutzer ausführen lassen (Agenten pushen nie); Verifikation: `git ls-remote origin refs/heads/refactorPED` entspricht dem lokalen `refactorPED`-HEAD.

## 2. Server-Checkout abgleichen

- [ ] 2.1 Auf `mintfv` `git fetch origin` ausführen und die uncommitteten Dateien prüfen; Verifikation: `style.css` und `mintfv-dashboard.json` haben weiterhin MD5 `59169bdf…` bzw. `efcecd65…`, und `origin/refactorPED` entspricht dem lokalen HEAD.
- [ ] 2.2 Die untracked Kopie `tests/mqtt-acl-smoke.sh` nach `diff -w` gegen die versionierte Datei abgleichen und bei funktionaler Gleichheit entfernen; Verifikation: kein Diff abgesehen von Einrückung, `mosquitto/config/backups/` bleibt vorhanden.
- [ ] 2.3 `git merge --ff-only origin/refactorPED` auf dem Server; Verifikation: `git log -1 --oneline` zeigt den lokalen HEAD und `git status --short` zeigt nur noch `mosquitto/config/backups/` als untracked.

## 3. Container neu bauen und verifizieren

- [ ] 3.1 `docker compose build selfservice mosquitto-reload` und `docker compose up -d selfservice mosquitto-reload`; Verifikation: beide Container sind `healthy`, `docker compose ps` zeigt keine Neustart-Schleife.
- [ ] 3.2 Live-Verifikation; Verifikation: `/selfservice/tenant/overview` liefert nicht mehr 404, `./tests/mqtt-acl-smoke.sh` meldet `SMOKE_OK`, `stat -c '%a %u:%g' mosquitto/config/mosquitto.acl` zeigt `660 2003:2100`, keine ungescopte ACL-Regel außer `master-admin`, Backup-Dateien vorhanden, InfluxDB liefert aktuelle Punkte aus `sensors`.

## Workflow follow-up

- Bei Abweichung: Rollback auf `e1b95a3` (Git-Reset und Image-Rebuild) nur mit separater, expliziter Freigabe; Datenbank bleibt auf `001_initial`.
- Change nach erfolgreicher Verifikation reviewen und archivieren.
