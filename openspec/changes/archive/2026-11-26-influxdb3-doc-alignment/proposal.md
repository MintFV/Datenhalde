# Proposal

## Why

Die Meta-Doku (`04`, `05`, `06`, `09`) und mehrere READMEs beschreiben InfluxDB 2.x/Flux-Begriffe wie Buckets, `from(bucket: …)`, `influx bucket create` und `influx backup` sowie drei konkurrierende DB-Namen (`mintfv`, `mydb`, `umweltbox*`). Produktiv läuft jedoch InfluxDB 3 Core 3.8.0 mit SQL/InfluxQL, Datenbank `mintfv`, Measurement `sensors`, und es gibt weder Plugins noch Trigger. Die Anweisungen in der Doku sind damit nicht ausführbar und wecken falsche Erwartungen an Zugang und Downsampling.

## What Changes

- Alle Flux- und v2-CLI-Beispiele in `04_InfluxDB_Schema.md`, `05_Onboarding_Prozess.md`, `06_Speicherplanung_und_Downsampling.md` und `09_LLM_Prompts_fuer_zukuenftige_Entwicklung.md` eindeutig als historisch markieren oder durch InfluxDB-3-Core-konforme SQL-/InfluxQL-Beispiele ersetzen.
- Den DB-Namen vereinheitlichen: `mintfv` als produktiver Name, `mydb` und `umweltbox*` als historische Platzhalter kennzeichnen.
- `influxdb/README.md`, `grafana/README.md`, `README.md` und `BACKUP.md` auf 3-Core-Begriffe umstellen (keine Buckets, Admin-Token-Datei, Port 8181, `influxdb3`-CLI); den Widerspruch zwischen `tar`-Backup und `influxdb3`-CLI auflösen.
- In `10_Doku_Code_Abgleich_2026-11.md` einen Abschnitt zum F6-Ist-Stand ergänzen: keine Plugins/Trigger, kein Downsampling, keine mandantenspezifischen Tokens (Core-CLI kennt nur `--admin`), `sensors` in `mintfv`.
- Retention/Downsampling, Tokens pro Tenant, Geo-Quellen und Public Data bleiben ausdrücklich als Zielbild gekennzeichnet; es wird **nichts** davon implementiert.
- Keine Änderung an `docker-compose.yaml`, Node-RED-Flow, Grafana-Provisioning, Dashboards, Tokens oder InfluxDB-Daten.

## Capabilities

### New Capabilities

(keine – reine Dokumentationsänderung ohne Verhaltensänderung, `skip_specs: true`)

### Modified Capabilities

(keine)

## Impact

- Betroffene Dateien: `docs/Projekt-Meta-Doku/04`, `05`, `06`, `09`, `10`; `influxdb/README.md`, `grafana/README.md`, `README.md`, `BACKUP.md`.
- Das provisioningierte Dashboard `grafana/dashboards/mintfv-dashboard.json` enthält veraltete Flux-Queries, wird aber **nicht** verändert (Laufzeit); es wird in der Doku als historisch erwähnt.
- Kein Einfluss auf den laufenden Stack; alle Belege bleiben im Repo und sind per `git diff` prüfbar.
