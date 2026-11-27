# Proposal

## Why

`docs/Projekt-Meta-Doku/10_Doku_Code_Abgleich_2026-11.md` ist die autoritative Ist-Stand-Datei, endet aber mit einem Nachtrag vom 26.11.; die Smoketest-MQTT-Umstellung vom 27.11. fehlt dort. `.github/README-CI.md` behauptet noch, es gebe „keinen Produktionszugriff, keine zusätzlichen Repository-Secrets" und Ergebnisse würden nicht ins Produktions-Grafana geschrieben — das ist seit dem archivierten Change `ci-smoketest-results-ingest` überholt. In `AGENTS.md` fehlt zudem die eng begrenzte Secret-Ausnahme, sodass ein nachfolgender Agent die Regel „keine GitHub-Secrets" zu streng anwenden könnte.

## What Changes

- Neuer Nachtrag 2026-11-27 im Doku-Code-Abgleich mit den verifizierten Fakten: MQTT-Publish unter `.../results/{prod|ci}`, `nodered-writer`-ACL, `source`-Tags, Dashboard `mintfv-smoketest`, GitHub-Secrets, echter CI-Lauf und `SMOKE_OK`.
- `.github/README-CI.md`: die Beschreibung des `MQTT ACL smoke`-Workflows auf den aktuellen Stand korrigieren (zwei gescopte Secrets, Publish in die Produktions-InfluxDB, sichtbar im Dashboard).
- `AGENTS.md` (Projekt): eng gefasste Regel ergänzen — genau die zwei Secrets `MQTT_SMOKE_USER` und `MQTT_SMOKE_PASS` mit der Identität `mintfv-smoketest` sind für den Smoketest-Ingest erlaubt; alle weiteren Secrets weiterhin nur nach Rückfrage.
- Verweis auf `11_Smoketest_Datenfluss.md` im Nachtrag, ohne das Diagramm zu duplizieren.
- Keine Änderung an Code, Compose-Konfiguration, Workflows oder laufenden Diensten.

## Capabilities

### New Capabilities

- keine

### Modified Capabilities

- keine (`skip_specs: true`, da reine Dokumentation und eine Agentenregel ohne Systemverhaltensänderung)

## Impact

- Geändert: `docs/Projekt-Meta-Doku/10_Doku_Code_Abgleich_2026-11.md`, `.github/README-CI.md`, `AGENTS.md`.
- Unverändert: alle Services, Secrets-Werte, Specs und der produktive Stack.
