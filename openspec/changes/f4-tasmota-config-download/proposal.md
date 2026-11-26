# Proposal

## Why

Der Selfservice zeigt heute nur einmalig die MQTT-Zugangsdaten und ein Tasmota-Panel mit maskiertem Passwort; der in `05_Onboarding_Prozess.md` §3 beschriebene Config-Download existiert nicht. Schulen sollen ein Tasmota-Gerät ohne manuelle Broker-/Topic-/ACL-Recherche anbinden können – mit einer Konfiguration, die zu den live bereits gültigen Topics und zur Node-RED-Verarbeitung passt.

## What Changes

- Neue Config-Erzeugung für Tasmota-Geräte als `tasmota_config.txt` mit einer `Backlog0`-Zeile (Broker, Port 8883, User, Passwort, Client, Topic, FullTopic, `SetOption3`, `TelePeriod`).
- Die Config entsteht im selben authentifizierten POST, der das Passwort ohnehin kennt (Account anlegen / Passwort ändern). Das Passwort wird **nicht** gespeichert, **nicht** geloggt und ist nicht über einen späteren GET erneut abrufbar.
- Clientseitiger QR-Code der Backlog-Zeile auf der Once-Credentials-Seite, erzeugt aus den dort einmalig angezeigten Werten; keine serverseitige Secret-Verarbeitung, keine neue Python-Abhängigkeit.
- Verbindliche FullTopic-Variante `umweltbox/%topic%/%prefix%/` mit `Topic = {tenant}/{device}`; die abweichende Angabe in `05_Onboarding_Prozess.md` wird korrigiert.
- Die Sensor-ACL-Leseregel in `service.py` wird auf `umweltbox/{tenant}/{device}/cmnd/#` korrigiert; das fordert die Spec `mqtt-access-control` bereits. Bestehende, manuell gepflegte Live-ACLs bleiben unberührt.
- Ein bei der Account-Erstellung gewähltes Gerät wird mit dem MQTT-Account verknüpft, damit Topic und Config auch nach einem Passwortwechsel reproduzierbar sind.
- Passwörter mit Zeichen, die die Tasmota-`Backlog`-Syntax brechen (insbesondere `;`), werden bei der Config-Erzeugung abgelehnt und mit einem klaren Hinweis gemeldet.

## Capabilities

### New Capabilities

- `device-config-download`: Erzeugung und Auslieferung gerätespezifischer Konfigurationsdateien und QR-Codes aus einmalig angezeigten, auf einen authentifizierten Tenant beschränkten Zugangsdaten. Startumfang: Tasmota.

### Modified Capabilities

– keine. Die bestehende Spec `mqtt-access-control` beschreibt den Ziel-ACL-Pfad bereits; die Abweichung liegt nur im Code und wird behoben.

## Impact

- Code: `selfservice/app/mqtt/routes.py`, `selfservice/app/mqtt/service.py`, `selfservice/app/templates/mqtt/credentials.html`, statische Assets für den clientseitigen QR-Code, Unit-Tests und Playwright-Suite `selfservice`.
- Daten: keine Migration; `Device.mqtt_account_id` wird beim Anlegen eines Sensor-Accounts gesetzt. Kein Password-Hash-Wechsel, kein Persistieren von Klartext-Passwörtern.
- Broker: geänderte ACL-Regeln nur für neu provisionierte Sensor-Accounts; Reload wie gewohnt über den bestehenden Trigger.
- Dokumentation: `docs/Projekt-Meta-Doku/05_Onboarding_Prozess.md`, `docs/TASMOTA_SETUP.md`, `docs/Projekt-Meta-Doku/10_Doku_Code_Abgleich_2026-11.md` (F4-Status).
- Abhängigkeiten: keine neuen Python-Pakete; die clientseitige QR-Bibliothek wird als statisches Asset eingebunden.
