# Tasks

## 1. Doku-Nachtrag

- [x] 1.1 Im Doku-Code-Abgleich einen Nachtrag 2026-11-27 mit den verifizierten Fakten zum MQTT-Ingest ergänzen — Verifikation: neuer Abschnitt existiert und nennt Topic-Schema, `source=prod|ci`, Dashboard-UID `mintfv-smoketest`, `nodered-writer`-Leseregel und den echten CI-Lauf `46066561520`
- [x] 1.2 Im Nachtrag auf `11_Smoketest_Datenfluss.md` und die beiden archivierten Change-Verzeichnisse verweisen — Verifikation: alle drei Pfade existieren und sind relativ korrekt angegeben
- [x] 1.3 `.github/README-CI.md` korrigieren: der `MQTT ACL smoke`-Workflow nutzt zwei gescopte Secrets, schreibt in die Produktions-InfluxDB und die Ergebnisse sind im Dashboard sichtbar — Verifikation: die alten Aussagen „kein Produktionszugriff", „keine zusätzlichen Repository-Secrets" und „kein Schreiben ins Dashboard" sind entfernt

## 2. Betriebsregel

- [x] 2.1 In `AGENTS.md` die eng gefasste Secret-Ausnahme ergänzen — Verifikation: Regel nennt exakt `MQTT_SMOKE_USER` und `MQTT_SMOKE_PASS`, die Identität `mintfv-smoketest` und die Topic-Grenze; für alle anderen Secrets gilt weiterhin Rückfrage
- [x] 2.2 Prüfen, dass keine Secret-Werte, Token oder Passwörter in den geänderten Doku-Dateien stehen — Verifikation: Suche nach `apiv3_`, `gho_` und konkreten Passwortwerten bleibt in den neuen Abschnitten ohne Treffer; der bereits akzeptierte D17-Finding in Zeile 95 bleibt unverändert dokumentiert

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
