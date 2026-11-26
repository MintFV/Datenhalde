# Design

## Context

Siehe `proposal.md` für die Motivation. Live-Befunde: Grafana provisioniert `mintfv-dashboard.json` nicht, weil die Datei Titel und UID unter `dashboard` verschachtelt hat („Dashboard title cannot be empty"). Die Datasource `PF1260F9C1BE25B8C` ist auf `version: SQL` konfiguriert; alle tatsächlich ausgeführten Queries anderer Dashboards sind `rawSql`. Es gibt keine Flux-Queries im laufenden Stack, keine Plugins und keine Trigger. `uwbox-overview.json` zeigt das funktionierende Muster für SQL-Panels.

## Goals / Non-Goals

**Goals:**
- Nach der Umsetzung existiert kein ausführbares Flux-Beispiel mehr in Doku oder Provisioning.
- Das zuvor tote Dashboard wird geladen und zeigt mit SQL dieselben Inhalte wie geplant.
- Die Dokumentation beschreibt nur noch Abfragen, die mit InfluxDB 3 Core funktionieren.

**Non-Goals:**
- Kein Downsampling, keine Retention, kein Plugin, kein Token-Provisioning.
- Keine Änderung an den bereits SQL-basierten Dashboards, an Compose, Node-RED, InfluxDB-Daten oder Tokens.
- Keine inhaltliche Neubewertung der Zielbild-Doku; historische Planung bleibt in `10` und in archivierten Changes dokumentiert.

## Decisions

**1. Historische Task-/Downsampling-Beispiele werden gelöscht.**
Der Nutzer hat das explizit gewählt. Die Blöcke in `04`, `06` und `09` beschreiben v2-Tasks und `umweltbox_*`-Buckets, die in 3 Core nicht existieren; mitgelöscht wird das `_tasks`-Monitoring in `06`. Die Abgleich-Doku `10` hält den Planungsstand weiterhin fest. Alternative „als historisch belassen" wurde verworfen, weil sie dem Auftrag widerspricht.

**2. Alle übrigen Flux-Beispiele werden in SQL überschrieben.**
Das betrifft die drei Abfragebeispiele in `04`, die fünf Kartenbeispiele in `07`, die Prompt-Texte in `09`, den Sequenzgraphen in `02` und die Vergleichstabelle in `08`. `07` erhält zusätzlich einen Status-Hinweis, weil dort bisher jeder Marker fehlt. Alternative „löschen" wurde nur für die Task-Beispiele gewählt, weil die Abfragebeispiele fachlich weiterhin nützlich sind.

**3. Das Dashboard wird repariert statt gelöscht.**
Der Nutzer hat sich für „reparieren + SQL" entschieden. Die Datei wird auf das Format der funktionierenden Dashboards umgestellt: `title`, `uid` und `panels` auf Top-Level (nicht unter `dashboard`). Die fünf Queries werden zu `rawSql`-Targets mit `editorMode: code`, `format: time_series` und `$__timeFilter(time)`. Die Template-Variable wird zu `SELECT DISTINCT tenant_id FROM sensors WHERE time > now() - interval '90 days' ORDER BY tenant_id`.

**4. Live-Verifikation ist Teil des Changes.**
Provisioning-Log, Grafana-API und die tatsächlichen Queries werden nach der Änderung geprüft. Ein rein statischer grep reicht nicht, weil das Dashboard vorher gar nicht geladen wurde.

## Risks / Trade-offs

- [Dashboard wird erstmals aktiv und verändert die Grafana-Ansicht] → vorher die Panels mit den SQL-Queries aus `uwbox-overview.json` abgleichen; nach dem Provisioning Log und API prüfen.
- [SQL-Dialekt der Grafana-InfluxDB-Datasource weicht ab] → dieselben Konstrukte nutzen, die bereits in `uwbox-overview.json` laufen (`$__timeFilter`, `ILIKE`, `rawSql`); live validieren.
- [File-Provider überschreibt Änderungen im 10-Sekunden-Takt] → Änderungen direkt in der Datei unter `grafana/dashboards/` vornehmen, nicht in der Grafana-UI.
- [Doku verliert Planungshistorie durch Löschen] → Verweis auf `10_Doku_Code_Abgleich_2026-11.md` und die archivierten Changes bleibt erhalten.

## Migration Plan

1. Historische Flux-Task-Blöcke in `04`, `06`, `09` löschen.
2. Übrige Flux-Beispiele in `02`, `04`, `07`, `08`, `09` auf SQL umschreiben; `07` mit Status-Hinweis versehen.
3. `mintfv-dashboard.json` auf Top-Level-Struktur und fünf SQL-Queries umstellen.
4. Live prüfen: kein „Dashboard title cannot be empty" im Log, Dashboard in der API sichtbar, SQL-Queries im Grafana-Log, Panels liefern Daten. Rollback über `git checkout` der geänderten Dateien; das Dashboard war vorher nicht aktiv.
