# Proposal

## Why

Der Smoketest-Datenfluss verteilt sich auf GitHub-Action, Skript, Mosquitto, Node-RED, InfluxDB und Grafana und existiert in zwei Herkunftspfaden (`prod` und `ci`). Die einzelnen Fakten stehen zwar in Code und Doku, sind aber nicht auf einen Blick erfassbar. Ein Mermaid-Diagramm macht Trigger, Verantwortlichkeiten, Topics und Sichtbarkeit konsistent sichtbar.

## What Changes

- Neue Datei `docs/Projekt-Meta-Doku/11_Smoketest_Datenfluss.md` mit einem Mermaid-Flowchart.
- Das Diagramm zeigt beide Auslöser (Push-getriggerte GitHub-Action und manueller Lauf auf `mintfv`), die drei Prüfungen (ACL, MQTT-Round-Trip, InfluxDB-Canary), den Publish über `smoketest/mintfv-smoketest/results/{prod|ci}`, die Verarbeitung in Node-RED, die Punkte in `mintfv`/`smoketest_results` sowie das Dashboard `mintfv-smoketest` mit `source`-Variable und CI-Panel.
- Ergänzende Kurzlegende zu Herkunft, Topic-Schema, Rollen und Fehlerpfad (`ok=0`).
- Keine Änderung an Code, Konfiguration, Specs oder laufendem Betrieb.

## Capabilities

### New Capabilities

- keine

### Modified Capabilities

- keine (`skip_specs: true`, da reine Dokumentation ohne Verhaltensänderung)

## Impact

- Neu: eine Markdown-Datei unter `docs/Projekt-Meta-Doku/`.
- Unverändert: alle Services, Topics, Tokens/Secrets, das Dashboard und die bestehenden Specs.
- Keine Auswirkung auf Produktion oder CI; kein Deploy und kein Reload von nginx oder Node-RED nötig.
