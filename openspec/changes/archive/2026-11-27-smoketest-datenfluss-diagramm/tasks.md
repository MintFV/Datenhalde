# Tasks

## 1. Diagramm-Datei

- [x] 1.1 Neue Datei `docs/Projekt-Meta-Doku/11_Smoketest_Datenfluss.md` mit deutschem Titel, kurzem Zweckabsatz und einem `mermaid`-Codeblock anlegen — Verifikation: Datei existiert und enthält genau einen `mermaid`-Fenced-Block
- [x] 1.2 Flowchart mit beiden Auslösern (`on: push` → `.github/workflows/mqtt-smoke.yml`; manuell → `tests/mqtt-acl-smoke.sh` auf `mintfv`) und den drei Prüfungen ACL, MQTT-Round-Trip und InfluxDB-Canary darstellen — Verifikation: alle fünf Knoten sind namentlich im Diagramm vorhanden
- [x] 1.3 Publish-Topic `smoketest/mintfv-smoketest/results/{prod|ci}`, Node-RED-Verarbeitung, InfluxDB `mintfv`/`smoketest_results` mit `source`, `run_id`, `sha`, `ref` sowie Dashboard `mintfv-smoketest` darstellen — Verifikation: Abgleich mit Workflow, Skript, Flow und Dashboard-JSON ergibt identische Namen
- [x] 1.4 Fehlerpfad mit `ok=0` als gestrichelte Kante und eine Legende zur Herkunft (`prod` = manuell auf `mintfv`, `ci` = isolierter Runner) ergänzen — Verifikation: Diagramm enthält beide Angaben und benennt CI ausdrücklich nicht als Produktionszustand

## 2. Abnahme

- [x] 2.1 Mermaid-Syntax prüfen — Verifikation: `mmdc`-Render fehlerfrei und visuell geprüft (top-down); Strukturcheck bestanden (5 Subgraphs, 15 Knoten, 18 Kanten, keine undefinierten Referenzen)
- [x] 2.2 Fachabgleich gegen den Quellcode und das archivierte Change-Design durchführen — Verifikation: keine abweichenden Topic-, Measurement- oder UID-Namen; die Rollen `mintfv-smoketest` und `nodered-writer` sind korrekt zugeordnet
- [x] 2.3 Sicherstellen, dass das Dokument keine Zugangsdaten enthält — Verifikation: Suche nach Token- und Passwortwerten bleibt ohne Treffer

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
