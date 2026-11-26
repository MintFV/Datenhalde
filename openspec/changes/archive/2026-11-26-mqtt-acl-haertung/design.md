# Design

## Context

Siehe `proposal.md` für die Motivation. Maßgeblich für diesen Entwurf ist der produktive Zustand auf `mintfv`: 57 Broker-Benutzer, davon vier mit ungescopten Regeln (`master-admin`, `nodered-writer`, `de-hh-mintfv-uwbox02`, `mcp-admin-user`), eine weltbeschreibbare ACL-Datei (`666`, `2003:mintfvdc`, GID 2100) und ein Node-RED-Flow mit genau einem `mqtt in` (`umweltbox/#`) sowie keinem `mqtt out`. `de-hh-mintfv-uwbox23` liefert nachweislich kontinuierlich Daten und dient als unveränderliches Referenzmuster. Der Selfservice schreibt ACL und Passwortdatei unter `fcntl.flock()` und löst danach den Reload aus; das Host-Skript `manage_mqtt_users.sh` ergänzt die ACL ebenfalls als Benutzer in GID 2100.

## Goals / Non-Goals

**Goals:**
- Least Privilege für die vier ungescopten Identitäten, ohne den laufenden Datenfluss zu unterbrechen.
- Jede Phase einzeln rückholbar machen, mit Beleg durch Broker-Logs und InfluxDB-Abfragen.
- Die Schreibfähigkeit des Selfservice und des Host-Skripts auf die ACL erhalten.
- Einen einfachen, read-only Smoketest bereitstellen, der vor und nach jeder Phase dieselben Prüfungen ausführt.

**Non-Goals:**
- Keine Änderung an `docker-compose.yaml`, Images, Ports oder am Deployment der vier lokalen Commits.
- Keine Korrektur des Node-RED-Parsers und keine Änderung am Measurement `sensors` oder an den Tags (`device_id=tele` aus der Tasmota-Topikform bleibt bestehen).
- Keine Änderung an `de-hh-mintfv-uwbox23`, an `master-admin`, an `monitoring` oder an korrekt gescopten Tenants.
- Kein Ausbau des Onboardings, der Config-Downloads oder der InfluxDB-3-Anbindung.

## Decisions

**1. uwbox02 erhält das exakte uwbox23-Muster.**
Die passenden scoped Zeilen stehen in der ACL bereits auskommentiert (Zeilen 339–340). Sie werden aktiviert und die Wildcard-Zeilen 337–338 entfernt. Alternative: Benutzer löschen – verworfen, weil er in den Logs der letzten 7 Tage noch connectet. Alternative: eigenes neues Schema erfinden – verworfen, weil das Referenzmuster bereits funktioniert.

**2. mcp-admin-user wird vollständig entfernt.**
Löschen aus der ACL und aus der Passwortdatei mit `mosquitto_passwd -D` im `mosquitto-admin`-Container, nicht durch Bearbeiten der Hash-Datei von Hand. Es gibt keinen Verweis in Code, Compose oder Skripten und keine Verbindung in 30 Tagen Logs. Alternative: auf bestimmte Topics reduzieren – verworfen, weil kein Verwender bekannt ist; ein externer Client außerhalb des Repos bleibt als Restrisiko vermerkt.

**3. nodered-writer erhält nur Lesezugriff.**
`readwrite #` wird durch `read umweltbox/#` ersetzt. Der Flow hat keine `mqtt out`-Knoten, benötigt also keine Schreibberechtigung. Alternative: unverändert behalten – verworfen, weil die Wildcard unnötig ist. Falls doch ein Publish-Pfad auftaucht, ist die Rücknahme über das Backup möglich.

**4. ACL-Dateirechte: `666` → `660`, Besitz `2003:2100` bleibt.**
Sowohl der Selfservice (`2007:2100`) als auch der Host-Benutzer `peddy` (Mitglied in GID 2100) schreiben die Datei; Mosquitto (`2003:2100`) liest sie. Gruppe behält daher Schreibrecht, „other" verliert jeden Zugriff. Alternative: `640` mit neuem Eigentümer – verworfen, weil das Host-Skript dann schreibrechtlos wäre.

**5. Änderungen erfolgen phasenweise mit SIGHUP-Reload.**
Der etablierte Weg `docker compose kill -s HUP mosquitto` wird genutzt. Nach jeder Phase: ACL-Backup mit Zeitstempel, Smoketest, Reload, erneuter Smoketest, Prüfung der Broker-Logs und einer InfluxDB-Abfrage. Alternative: alle Änderungen in einem Schritt – verworfen, weil die Fehlerquelle bei ausbleibenden Daten dann nicht eingrenzbar wäre.

**6. `mintfv-smoketest` als gescopte Testidentität.**
Der Name folgt der Konvention der Dienstbenutzer (`nodered-writer`, `master-admin`) und vermeidet den Anschein eines Geräte- oder Tenant-Users. Rechte: `write` und `read` auf `smoketest/mintfv-smoketest/#`, `read` auf `umweltbox/de-hh-mintfv-uwbox23/#` und `read $SYS/broker/version`. Der Round-Trip läuft bewusst außerhalb von `umweltbox/#`, weil Node-RED nur dieses Präfix abonniert und der Test sonst Produktionsdaten in `sensors` schreiben würde. Credentials liegen nur in `.env`; das Skript `tests/mqtt-acl-smoke.sh` liest sie aus Umgebungsvariablen. Alternative 1: vorhandene Playwright-Suite nutzen – verworfen, weil `tests/specs/smoke.spec.ts` nur `setContent` prüft und keine Dienste anspricht. Alternative 2: echte Gerätecredentials wiederverwenden – verworfen wegen Geheimnisverteilung und fehlender Isolierung. Alternative 3: rein statische Prüfung ohne Testuser – verworfen, weil sie keine wirksame ACL-Mechanik testet. Der zusätzliche Benutzer ist ein bewusster Trade-off in einem Change, der ansonsten ungenutzte Identitäten entfernt; er ist eng gescopt und ersetzt riskantere Prüfmethoden.

## Risks / Trade-offs

- [uwbox02 publiziert außerhalb des eigenen Namespace] → Daten bleiben weg; mit dem Backup sofort rückholbar, vorher zwei Tage ohne Daten beobachtet.
- [mcp-admin-user wird doch extern genutzt] → Verbindungsfehler eines unbekannten Clients; Identität aus Backup neu anlegen, ohne die gehärteten Regeln anzutasten.
- [nodered-writer benötigt doch Schreibzugriff] → InfluxDB erhält keine Punkte; Rücknahme über Backup, danach Ursache im Flow suchen.
- [Rechteänderung verhindert Selfservice-Schreibzugriff] → ACL-Updates aus der Weboberfläche scheitern; vorher und nachher einen kontrollierten Schreibtest aus dem Selfservice-Container durchführen.
- [Reload greift nicht] → alte ACL bleibt aktiv; über `docker compose logs mosquitto` prüfen und SIGHUP erneut auslösen.
- [Bestehende ACL wurde bereits manipuliert] → Backup vor der ersten Änderung sichert den Ist-Zustand; ein Diff zeigt unerwartete Regeln.
- [Smoketest ist flaky, weil uwbox23 nur intermittierend connectet] → großzügiges Timeout und InfluxDB-Abfrage als primärer Beleg; ein fehlgeschlagener Lauf wird wiederholt, bevor er als Abweichung gilt.
- [Testcredentials landen im Repo oder in Logs] → nur `.env`, Ausgabe ausschließlich von Statuswerten, niemals Passwörter oder Hashes.
- [Zusätzliche Identität wird als neues Loch missverstanden] → im Review explizit auf das enge Rechtset und den Zweck verweisen; bei Wegfall des Smoketests wird die Identität wieder entfernt.

## Migration Plan

1. **Vorbereitung:** `mintfv-smoketest` in ACL und Passwortdatei anlegen, Credentials in `.env` eintragen, Skript `tests/mqtt-acl-smoke.sh` implementieren und eine Baseline protokollieren.
2. **Baseline sichern:** ACL mit Zeitstempel kopieren, `de-hh-mintfv-uwbox23`-Daten und Broker-Logs als Referenz festhalten.
3. **Phase 1 – uwbox02:** Smoke vor der Änderung, Wildcard-Zeilen durch das Referenzmuster ersetzen, SIGHUP, Smoke danach, Verbindungen und InfluxDB-Punkte prüfen.
4. **Phase 2 – mcp-admin-user:** Smoke vor der Änderung, ACL-Block entfernen, Passwort-Eintrag per `mosquitto_passwd -D` löschen, SIGHUP, Smoke danach, übrige Benutzer prüfen.
5. **Phase 3 – nodered-writer:** Smoke vor der Änderung, auf `read umweltbox/#` reduzieren, SIGHUP, Smoke danach, InfluxDB-Schreibfluss prüfen.
6. **Phase 4 – Dateirechte:** Smoke vor der Änderung, `chmod 660` bei unverändertem Besitz `2003:2100`, Schreibtest aus dem Selfservice-Container, Smoke danach.
7. **Rollback je Phase:** gesicherte ACL zurückspielen, SIGHUP, Smoke erneut ausführen und Referenzgerät sowie InfluxDB prüfen. Die Passwortdatei wird bei Bedarf aus deren eigener Sicherung wiederhergestellt.
