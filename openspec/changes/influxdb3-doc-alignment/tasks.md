# Tasks

## 1. Meta-Doku: historische Beispiele markieren

- [ ] 1.1 Alle Flux- und v2-CLI-Beispiele in `04_InfluxDB_Schema.md`, `05_Onboarding_Prozess.md`, `06_Speicherplanung_und_Downsampling.md` und `09_LLM_Prompts_fuer_zukuenftige_Entwicklung.md` mit dem Marker „historisch – InfluxDB 3 Core unterstützt kein Flux" versehen; Verifikation: `grep -n 'from(bucket:\|influx bucket\|influx backup\|Flux'` zeigt nur noch markierte Treffer.
- [ ] 1.2 DB-Namen in denselben Dateien vereinheitlichen: `mintfv` als produktiver Name, `mydb` und `umweltbox*` als historische Platzhalter kennzeichnen; Verifikation: unmarkierte Treffer von `mydb` und `umweltbox*` sind nicht mehr vorhanden.
- [ ] 1.3 Ein ausführbares SQL-Beispiel für den heutigen Schreibpfad ergänzen (Datenbank `mintfv`, Measurement `sensors`); Verifikation: das Beispiel entspricht `nodered/data/flows.json` und ist gegen die live CLI ausführbar.

## 2. READMEs und Backup-Doku

- [ ] 2.1 `influxdb/README.md` und `grafana/README.md` auf InfluxDB 3 Core umstellen (SQL/InfluxQL, Port 8181, Admin-Token-Datei, keine v2-Buckets); Verifikation: keine unmarkierten v2-Bucket-Befehle mehr, DB-Name durchgängig `mintfv`.
- [ ] 2.2 Den Widerspruch zwischen `tar`-Backup und `influxdb3`-CLI in `BACKUP.md` und `README.md` auflösen; Verifikation: beide Dateien nennen denselben maßgeblichen Weg und kennzeichnen den anderen als Alternative.

## 3. Abgleich und Abschluss

- [ ] 3.1 Abschnitt 8 in `10_Doku_Code_Abgleich_2026-11.md` mit dem F6-Ist-Stand ergänzen: keine Plugins/Trigger, kein Downsampling, keine mandantenspezifischen Tokens, `sensors` in `mintfv`, Dashboard `mintfv-dashboard.json` als historisch; Verifikation: Abschnitt vorhanden und deckt sich mit den Live-Befunden.
- [ ] 3.2 Gesamtprüfung; Verifikation: `git diff --stat` enthält ausschließlich `.md`-Dateien, keine Änderung an `docker-compose.yaml`, Node-RED, Grafana-Provisioning oder Tokens, und `openspec validate influxdb3-doc-alignment` ist erfolgreich.

## Workflow follow-up

- Change nach Freigabe reviewen und archivieren.
