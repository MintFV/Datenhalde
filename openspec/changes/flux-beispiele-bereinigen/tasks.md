# Tasks

## 1. Historische Flux-Task-Blöcke löschen

- [ ] 1.1 Die als historisch markierten Downsampling-/Task-Beispiele in `04_InfluxDB_Schema.md` und `06_Speicherplanung_und_Downsampling.md` löschen, einschließlich des `_tasks`-Monitorings; Verifikation: `grep -n 'option task\|from(bucket: "_tasks")'` findet keine Treffer mehr in diesen Dateien.
- [ ] 1.2 Die veralteten Flux-Task-Prompts in `09_LLM_Prompts_fuer_zukuenftige_Entwicklung.md` (Prompt 3.1 und Template 2) löschen; Verifikation: keine `InfluxDB Task (Flux)`-Anweisung mehr, der globale Stack-Hinweis bleibt erhalten.

## 2. Übrige Flux-Beispiele auf SQL umschreiben

- [ ] 2.1 Die drei Flux-Query-Beispiele in `04_InfluxDB_Schema.md` durch SQL-Äquivalente für `mintfv`/`sensors` ersetzen; Verifikation: keine `from(bucket:`-Treffer mehr, die Beispiele nutzen `SELECT … FROM sensors`.
- [ ] 2.2 Die fünf Kartenbeispiele in `07_Kartenvisualisierung.md` auf SQL umschreiben und einen Status-Hinweis ergänzen; Verifikation: keine `from(bucket:`- oder `|>`-Treffer mehr und ein sichtbarer Hinweis auf InfluxDB 3 Core.
- [ ] 2.3 Die veralteten Prompt-Texte in `09` (2.x, 3.2, 4.1, 7.2, Template 3) auf SQL umformulieren; Verifikation: keine unmarkierten Flux-Anweisungen mehr in den Prompt-Texten.
- [ ] 2.4 `02_Architektur_Uebersicht.md` („Query (Flux)" → SQL/InfluxQL), `08_Referenzprojekte.md` (Vergleichstabelle) sowie die Verweise in `AGENTS.md` und `10_Doku_Code_Abgleich_2026-11.md` anpassen; Verifikation: keine unmarkierten „Flux"-Erwähnungen außerhalb der Abgleich-/Archiv-Dokus.

## 3. Grafana-Dashboard reparieren

- [ ] 3.1 `grafana/dashboards/mintfv-dashboard.json` auf Top-Level-`title`/`uid` umstellen und die fünf Queries (drei Zeitreihen, Tabelle, Template-Variable) auf `rawSql` umschreiben; Verifikation: `jq` oder `python3 -m json.tool` akzeptiert die Datei, grep findet kein `queryType: flux` und kein `from(bucket:`.
- [ ] 3.2 Live-Prüfung nach dem Provisioning; Verifikation: kein „Dashboard title cannot be empty" im Grafana-Log, Dashboard in der API-Liste sichtbar, Grafana-Log zeigt SQL-Queries und die Panels liefern Daten.

## 4. Abschluss

- [ ] 4.1 Gesamtprüfung; Verifikation: `grep -rn 'from(bucket:\|option task\|queryType.: .flux'` findet im Repo nur noch Treffer in archivierten OpenSpec-Artefakten und im Abgleich-Dokument, `openspec validate flux-beispiele-bereinigen` ist erfolgreich und `git diff --stat` zeigt nur die geplanten Doku-/Dashboard-Dateien.

## Workflow follow-up

- Change nach Live-Verifikation reviewen und archivieren.
