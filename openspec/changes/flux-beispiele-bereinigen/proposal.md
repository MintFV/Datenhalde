# Proposal

## Why

Im Repo finden sich rund 21 ausführbare Flux-Snippets in sieben Dokumenten sowie fünf Flux-Queries im provisioningierten Grafana-Dashboard `mintfv-dashboard.json`. Der produktive Stack nutzt InfluxDB 3 Core mit SQL-Datasource; dort läuft kein Flux. Das Dashboard wird zusätzlich beim Provisioning mit „Dashboard title cannot be empty" abgelehnt und ist deshalb nie aktiv. Die Doku `07_Kartenvisualisierung.md` enthält sogar völlig unmarkierte Flux-Beispiele.

## What Changes

- Die als historisch markierten Downsampling-/Task-Beispiele in `04`, `06` und `09` (inkl. des `_tasks`-Monitorings) werden **gelöscht**; der Planungsstand bleibt in `10_Doku_Code_Abgleich_2026-11.md` dokumentiert.
- Alle übrigen Flux-Beispiele werden **auf die aktuelle Situation umgeschrieben**: SQL-Abfragen in `04`, fünf Kartenbeispiele in `07`, Prompt-Texte in `09`, der Architekturgraph in `02` und die Vergleichstabelle in `08`. Die bereits SQL-basierten Abschnitte in `05` bleiben unverändert.
- `grafana/dashboards/mintfv-dashboard.json` wird provisioningfähig gemacht (nicht-leerer Titel/UID auf Top-Level) und seine fünf Queries (drei Zeitreihen, eine Tabelle, eine Template-Variable) werden auf SQL/`rawSql` umgestellt. Das Dashboard wird damit erstmals tatsächlich geladen.
- `AGENTS.md` und `10_Doku_Code_Abgleich_2026-11.md` erhalten Hinweise auf die bereinigte Datei `07`; archivierte OpenSpec-Artefakte bleiben als historische Planungsdokus unangetastet.
- Keine Änderung an `docker-compose.yaml`, Node-RED-Flow, InfluxDB-Daten, Tokens oder an den bereits SQL-basierten Dashboards.

## Capabilities

### New Capabilities

- `grafana-dashboards`: Anforderungen an provisioningfähige Grafana-Dashboards, deren Queries mit der InfluxDB-3-Core-SQL-Datasource kompatibel sind.

### Modified Capabilities

(keine)

## Impact

- Geänderte Doku: `docs/Projekt-Meta-Doku/02`, `04`, `06`, `07`, `08`, `09`, `10`; `AGENTS.md`.
- Geänderte Laufzeitkonfiguration: `grafana/dashboards/mintfv-dashboard.json` (wird per Provisioning alle 10 s neu geladen).
- Nach der Umsetzung muss live geprüft werden, dass das Dashboard ohne Provisionierungsfehler geladen wird und seine Panels SQL-Queries ausführen.
