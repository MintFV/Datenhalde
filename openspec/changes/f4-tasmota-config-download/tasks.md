# Tasks

## 1. ACL und Geräteverknüpfung angleichen

- [x] 1.1 Leseregel in `selfservice/app/mqtt/service.py` auf `umweltbox/{tenant}/{device}/cmnd/#` ändern und die Erwartung in `selfservice/tests/test_mqtt_acl.py` anpassen; verifiziert mit `cd selfservice && pytest -q tests/test_mqtt_acl.py`.
- [x] 1.2 Bei der Account-Anlage in `selfservice/app/mqtt/routes.py` das gewählte Gerät per `Device.mqtt_account_id` verknüpfen und eine bereits vergebene Verknüpfung mit Hinweis ablehnen; verifiziert durch einen neuen Testfall in `selfservice/tests/test_mqtt_acl.py` oder `test_tenant.py` und `cd selfservice && pytest -q`.

## 2. Backlog-Builder und Passwortprüfung

- [x] 2.1 Reine Builder-Funktion für die `Backlog0`-Zeile ergänzen: `MqttHost`, `MqttPort 8883`, `MqttUser`, `MqttPassword`, `MqttClient`, `Topic umweltbox/{tenant}/{device}`, `FullTopic umweltbox/%topic%/%prefix%/`, `SetOption3 1`, `TelePeriod 300`; verifiziert durch exakte String-Vergleiche in einem neuen `selfservice/tests/test_tasmota_config.py` (`cd selfservice && pytest -q tests/test_tasmota_config.py`).
- [x] 2.2 Passwörter mit `;`, `"`, `\`, Zeilenumbruch oder Steuerzeichen vor der Config-Erzeugung abweisen und einen verständlichen Hinweis ausgeben; verifiziert durch parametrisierte Unit-Tests in `test_tasmota_config.py`.
- [x] 2.3 Die Views `create()` und `change_password()` reichen die Backlog-Zeile nur bei verknüpftem Gerät vom Typ `tasmota` an das Template weiter; verifiziert durch Unit-Tests für Tasmota, `rpi` und Account ohne Gerät (`cd selfservice && pytest -q`).

## 3. Datei-Download und QR im Browser

- [x] 3.1 `selfservice/app/templates/mqtt/credentials.html` um Download-Schaltfläche (Blob `tasmota_config.txt`) und QR-Container ergänzen; beide erzeugen ihren Inhalt aus dem einmalig gerenderten Backlog-String ohne weitere Anfrage mit dem Passwort; verifiziert durch einen Playwright-Fall in der Suite `selfservice` (`./tests/run-tests.sh selfservice`), der Dateiname, Dateiinhalt und QR-Inhalt prüft.
- [x] 3.2 Eine kleine MIT-lizenzierte clientseitige QR-Bibliothek als statisches Asset unter `selfservice/app/static/js/` einbinden, ohne neue Python-Abhängigkeit; verifiziert durch Laden der Seite im Browser ohne Konsolenfehler und unveränderte `selfservice/requirements.txt`.

## 4. Dokumentation und Abnahme

- [x] 4.1 `docs/Projekt-Meta-Doku/05_Onboarding_Prozess.md` §3 auf `FullTopic umweltbox/%topic%/%prefix%/` mit `Topic umweltbox/{tenant}/{device}` korrigieren, `docs/TASMOTA_SETUP.md` um den Download-Hinweis ergänzen und den F4-Status in `docs/Projekt-Meta-Doku/10_Doku_Code_Abgleich_2026-11.md` aktualisieren; verifiziert durch `git diff --check` und Abgleich der genannten Topic-Zeilen.
- [x] 4.2 Lokale Gesamtprüfung: `ruff check selfservice`, `mypy --config-file selfservice/pyproject.toml selfservice`, `cd selfservice && pytest -q` sowie der Playwright-Fall „Tasmota config download and QR use the same backlog“; alle grün.
- [ ] 4.3 Nach dem Produktiv-Deploy: `./tests/mqtt-acl-smoke.sh` muss `SMOKE_OK` melden. Steht aus, solange kein Deploy erfolgt ist.

## Workflow follow-up

- Nach Review und Freigabe den Change archivieren und die neue Capability `device-config-download` in die Haupt-Specs übernehmen.
