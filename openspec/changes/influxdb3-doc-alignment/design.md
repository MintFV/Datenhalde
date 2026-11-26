# Design

## Context

Siehe `proposal.md` für die Motivation. Maßgeblich ist der produktive Stand: InfluxDB 3 Core 3.8.0 auf Port 8181 (nur intern), Datenbanken `_internal`, `mintfv` und `umweltbox`, Measurement `sensors` in `mintfv` mit den Tags `tenant_id`, `device_id`, `category`, `sensor_type` und dem Field `value`. Node-RED schreibt über `/api/v3/write_lp?db=mintfv&precision=ns`. Es sind keine Plugins und keine Trigger installiert; `influxdb3 create token` bietet nur `--admin`. Grafana ist per SQL-Datasource an `mintfv` angebunden. Ein zuvor archivierter Change hat den ACL-Stand bereits im Abgleich-Dokument (Abschnitt 7) nachgezogen.

## Goals / Non-Goals

**Goals:**
- Dokumentation so umstellen, dass alle verbleibenden Beispiele mit dem produktiven 3-Core-Stack übereinstimmen oder klar als historisch gekennzeichnet sind.
- Zielbild und Ist-Stand trennbar machen, damit spätere Changes (Retention, Downsampling, Tenant-Zugang) auf einer verlässlichen Basis aufbauen.

**Non-Goals:**
- Keine Laufzeitänderung: keine Compose-Änderung, kein Neustart, keine Token-, Datenbank-, Grafana- oder Node-RED-Änderung.
- Kein Downsampling, keine Retention, kein Provisioning und keine neuen Specs (`skip_specs: true`).
- Keine inhaltliche Neubewertung des Zielbilds aus `04`/`06` – es wird nur gekennzeichnet, nicht verworfen.

## Decisions

**1. Kein Spec-Delta.**
Es ändert sich kein systembeobachtbares Verhalten, nur die Beschreibung. `skip_specs: true` im `.openspec.yaml` ist deshalb korrekt; ein künstliches Requirement würde die Spec verunreinigen.

**2. Historische Blöcke markieren statt ersetzen.**
Die Meta-Doku dient auch als Planungsgrundlage. Statt Flux-/v2-Beispiele still durch SQL zu ersetzen, erhalten sie einen eindeutigen Hinweis „historisch – InfluxDB 3 Core unterstützt kein Flux". Neue, ausführbare Beispiele werden daneben gestellt. Alternative: komplettes Entfernen – verworfen, weil damit Planungshistorie verloren ginge.

**3. `mintfv` ist der kanonische DB-Name.**
`mydb` und `umweltbox*` bleiben als historische Platzhalter erkennbar. Das entspricht Compose, Node-RED, Grafana-Provisioning und der Realität; `umweltbox` existiert zwar als separate DB mit einer gleichnamigen Tabelle, ist aber nicht der aktive Schreibpfad.

**4. Provisionierte Dashboards bleiben unangetastet.**
`grafana/dashboards/mintfv-dashboard.json` enthält Flux-Queries und wird von Grafana automatisch geladen. Eine Änderung wäre eine Laufzeitänderung und daher out of scope; stattdessen wird der Dashboard-Status in der Doku vermerkt.

**5. Abgleich-Doku wird ergänzt, nicht umgeschrieben.**
Abschnitt 7 (`mqtt-acl-haertung`) bleibt als Zeitdokument; ein neuer Abschnitt hält den F6-Ist-Stand fest. So bleibt die Abfolge der Erkenntnisse nachvollziehbar.

## Risks / Trade-offs

- [Doppelte Aussagen in der Doku] → einheitlicher Marker für historische Abschnitte; jede geänderte Datei enthält einen Verweis auf den kanonischen Ist-Stand in Abschnitt 8 von `10`.
- [Leser führt ein als historisch markiertes Beispiel trotzdem aus] → Warnhinweis direkt am Beispiel, nicht nur im Vorwort.
- [Doku-Korrektur wird als Verhaltensänderung missverstanden] → `skip_specs: true` und explizite Non-Goals im Proposal.
- [Backup-Anleitung bleibt widersprüchlich] → **Korrektur während der Umsetzung:** InfluxDB 3 Core bietet kein `influxdb3 backup`, sondern nur `query`/`write` für logische Exporte. Maßgeblich ist der Dateisystem-Snapshot von `influxdb/data/` (konsistent mit gestopptem Container per `tar`, laufend per `rsync` wie in `BACKUP.md`); `influx backup` bleibt historisch.

## Migration Plan

1. Flux-/v2-Beispiele in `04`, `05`, `06`, `09` inventarisieren und markieren.
2. DB-Namen und READMEs vereinheitlichen; Backup-Widerspruch auflösen.
3. Abschnitt 8 in `10_Doku_Code_Abgleich_2026-11.md` mit dem F6-Ist-Stand ergänzen.
4. Gesamtprüfung: `git diff --stat` darf nur `.md`-Dateien enthalten; stichprobenhaft ein SQL-Beispiel gegen die live CLI prüfen. Rollback ist ein einfacher `git checkout` der betroffenen Doku-Dateien.
