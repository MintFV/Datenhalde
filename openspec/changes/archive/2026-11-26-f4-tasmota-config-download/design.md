# Design

## Context

Der Selfservice rendert `mqtt/credentials.html` bereits im selben POST, in dem das Klartext-Passwort vorliegt (Anlage oder Passwortänderung); gespeichert wird nur der PBKDF2-Hash in `mosquitto.passwd`. Das Tasmota-Panel im Dashboard zeigt ein maskiertes Passwort und `FullTopic umweltbox/%topic%/%prefix%/`. `Device.device_type` kennt `tasmota`, `rpi`, `telegraf`; ein bei der Account-Anlage gewähltes Gerät wird bisher **nicht** mit dem MQTT-Account verknüpft (`Device.mqtt_account_id` bleibt leer). Die Live-ACL und die Spec `mqtt-access-control` nutzen `read umweltbox/{tenant}/{device}/cmnd/#`, der Code in `mqtt/service.py` dagegen `read umweltbox/{tenant}/cmnd/{device}/#`. `05_Onboarding_Prozess.md` enthält eine davon abweichende, intern widersprüchliche FullTopic-Angabe. Produktiv sind aktuell 0 Tenants/Devices/Accounts, die ACLs werden manuell gepflegt.

## Goals / Non-Goals

**Goals:**

- Eine copy-paste-fähige Tasmota-`Backlog0`-Zeile und ein passender QR-Code, erzeugt aus den einmalig sichtbaren Werten.
- Topic-, ACL- und Node-RED-Kompatibilität ohne manuelle Eingriffe.
- Kein zweiter Weg für das Klartext-Passwort: keine Persistenz, kein Log, kein späterer GET.

**Non-Goals:**

- Configs für `rpi`/`telegraf`, Onboarding-Wizard (F5), InfluxDB-/Grafana-Tokens (F6), Live-Verifikation (F7).
- Änderungen an bestehenden, manuell gepflegten Live-ACLs oder an der Datenbankschema-Version.
- Serverseitige QR-Erzeugung, Passwort-Wiederherstellung oder erneuter Download nach Verlassen der Seite.

## Decisions

1. **Erzeugung im bestehenden POST, Download und QR clientseitig.** Eine reine Builder-Funktion im Selfservice formt aus Tenant, Gerät, Account und dem übergebenen Passwort die Backlog-Zeile; `create()` und `change_password()` reichen sie an `credentials.html` weiter. Button und QR erzeugen Datei bzw. Bild im Browser aus dem bereits im DOM stehenden String.
   - Alternative: serverseitiger Attachment-Endpoint mit verstecktem Passwortfeld. Verworfen: das Passwort würde ein zweites Mal durch den Server laufen, CSRF/Logging-Risiko und kein Gewinn für den Nutzer.
   - Alternative: GET-Download mit Token. Verworfen: Token wäre ein Persistenz-/Reabruf-Weg für das Secret.

2. **FullTopic `umweltbox/%topic%/%prefix%/`, `Topic = {tenant}/{device}`.** Ergebnis: `umweltbox/{tenant}/{device}/tele/SENSOR` bzw. `.../cmnd/#`. Das liegt im ACL-Schreibbereich, wird von `umweltbox/#` erfasst und entspricht `TASMOTA_SETUP.md` sowie dem Dashboard-Panel. `05` wird auf diese Variante korrigiert.
   - Alternative `%prefix%/%topic%/` aus `05 §3`: verworfen, weil Topics dann nicht mit `umweltbox/` beginnen und weder ACL noch Node-RED sie sehen.

3. **ACL-Code an die bestehende Spec angleichen.** `_acl_topic_lines()` erhält `read umweltbox/{tenant}/{device}/cmnd/#`; `test_mqtt_acl.py` wird angepasst. Kein Spec-Delta nötig – die Anforderung existiert bereits, nur die Implementierung weicht ab. Der Smoketest `tests/mqtt-acl-smoke.sh` bleibt unverändert, da keine Live-ACL angefasst wird.

4. **Gerät bei Account-Anlage verknüpfen.** Wird bei der Anlage ein Gerät gewählt, wird `Device.mqtt_account_id` auf den neuen Account gesetzt. Damit sind Topic und Config auch nach einem Passwortwechsel bestimmbar. Ist das Gerät bereits einem anderen Account zugeordnet, bricht die Anlage mit einem Hinweis ab.
   - Alternative: Gerätedaten erneut im Formular abfragen. Verworfen: doppelte Eingabe und erneute Fehlerquelle.

5. **Backlog-kritische Zeichen abfangen.** Vor der Config-Erzeugung wird das Passwort auf `;`, `"`, `\`, Zeilenumbruch und Steuerzeichen geprüft. Bei Verstoß wird die Config nicht ausgeliefert und ein Hinweis angezeigt; die Account-Anlage selbst bleibt erfolgreich, damit die MQTT-Funktion nicht durch Tasmota-Syntax blockiert wird.
   - Alternative: Zeichen global in den Formularen verbieten. Verworfen: würde auch Nicht-Tasmota-Accounts unnötig einschränken.

6. **QR-Bibliothek als statisches Asset.** Eine kleine MIT-lizenzierte clientseitige Bibliothek wird unter `selfservice/app/static/js/` eingebunden; kein neues Python-Paket, keine externe Laufzeit-Abhängigkeit. Die Skriptblöcke bleiben in `credentials.html` (`extra_scripts`).
   - Alternative CDN: verworfen wegen zusätzlichem Netzwerk-/SRI-Aufwand und schwacher Kontrolle über die geladene Version.

## Risks / Trade-offs

- **Passwort im Browser-DOM:** wie heute schon bei `credentials.html`. → Hinweis auf einmalige Anzeige und QR-Sichtschutz; kein Server-Store.
- **Backlog-Injektion:** → Validierung vor der Erzeugung (Entscheidung 5) mit Unit-Test.
- **JavaScript aus:** Datei-Download und QR fallen weg, Zugangsdaten bleiben sichtbar. → akzeptiert; keine serverseitige Secret-Kopie.
- **Produktions-DB leer:** echte Abnahme erst nach Anlage eines Tenants möglich. → Abnahme mit Test-Tenant, Live-ACL bleibt unangetastet.
- **Doc-Divergenz:** `05` wird korrigiert, historische Beispiele bleiben als Zielbild gekennzeichnet. → Abgleichseintrag in `10` aktualisieren.

## Migration Plan

Keine DB-Migration, kein Image-Wechsel anderer Dienste, keine nginx-Änderung. Nach dem Selfservice-Deploy: `./tests/mqtt-acl-smoke.sh` muss `SMOKE_OK` melden; anschließend Test-Account mit Tasmota-Gerät anlegen, Config-Download und QR gegen Topic/ACL prüfen. Rollback: vorheriges Selfservice-Image; bestehende Accounts und ACLs sind davon unabhängig.

## Open Questions

Keine. Die drei fachlichen Entscheidungen (Gerätetypen, QR, FullTopic) sind getroffen und in den Specs festgehalten.
