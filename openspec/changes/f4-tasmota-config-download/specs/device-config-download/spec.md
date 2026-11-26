# Spec Delta

## Purpose

Diese Capability beschreibt, wie der Selfservice aus einmalig angezeigten, auf einen authentifizierten Tenant beschränkten MQTT-Zugangsdaten eine gerätespezifische Konfigurationsdatei und einen QR-Code bereitstellt, damit Tasmota-Geräte ohne manuelle Nachschlüsselung angebunden werden können.

## ADDED Requirements

### Requirement: Config ist an Tenant und Tasmota-Gerät gebunden

Die Config-Erzeugung SHALL nur für einen angemeldeten Benutzer mit aktivem Tenant und einen MQTT-Account mit verknüpftem Gerät vom Typ `tasmota` verfügbar sein. Für andere Gerätetypen oder Accounts ohne Gerät SHALL keine Tasmota-Config angeboten werden.

#### Scenario: Sensor-Account mit Tasmota-Gerät

- **WHEN** ein angemeldeter Benutzer mit aktivem Tenant einen Sensor-Account mit einem verknüpften Gerät vom Typ `tasmota` anlegt
- **THEN** enthält die Antwort eine herunterladbare `tasmota_config.txt`

#### Scenario: Kein passendes Gerät

- **WHEN** der MQTT-Account kein verknüpftes Gerät oder ein Gerät vom Typ `rpi` oder `telegraf` hat
- **THEN** wird keine Tasmota-Config angeboten und die Zugangsdaten werden unverändert angezeigt

### Requirement: Backlog-Zeile folgt dem Live-Topic-Schema

Die erzeugte Datei SHALL genau eine `Backlog0`-Zeile mit `MqttHost`, `MqttPort 8883`, `MqttUser`, `MqttPassword`, `MqttClient`, `Topic umweltbox/{tenant}/{device}`, `FullTopic umweltbox/%topic%/%prefix%/`, `SetOption3 1` und `TelePeriod 300` enthalten.

#### Scenario: Topic und FullTopic

- **WHEN** die Config für Tenant `de-hh-gs-test` und Gerät `esp01` erzeugt wird
- **THEN** lauten die Einträge `Topic umweltbox/de-hh-gs-test/esp01` und `FullTopic umweltbox/%topic%/%prefix%/`

#### Scenario: Kompatibilität mit Broker und Node-RED

- **WHEN** das Gerät mit dieser Config Telemetrie sendet
- **THEN** liegt das Topic unter `umweltbox/{tenant}/{device}/tele/` im ACL-Schreibbereich und wird vom Abonnement `umweltbox/#` erfasst

### Requirement: Passwort bleibt einmalig und wird nicht gespeichert

Das Klartext-Passwort SHALL ausschließlich in der einmaligen Antwort sowie in der daraus erzeugten Datei und dem QR-Code vorkommen. Es SHALL nicht in der Datenbank, nicht in Logs und nicht über einen späteren GET-Abruf erneut verfügbar sein.

#### Scenario: Einmalige Auslieferung

- **WHEN** ein MQTT-Account angelegt oder sein Passwort geändert wird
- **THEN** stehen Passwort und Config nur in dieser Antwort und der Broker speichert ausschließlich den Hash

#### Scenario: Kein späterer Abruf

- **WHEN** der Benutzer danach die MQTT-Übersicht oder das Dashboard öffnet
- **THEN** ist das Passwort nicht erneut abrufbar und es gibt keinen Download mit dem alten Passwort

### Requirement: QR-Code kodiert dieselbe Backlog-Zeile clientseitig

Der QR-Code SHALL clientseitig aus den einmalig angezeigten Werten erzeugt werden und SHALL exakt die Backlog-Zeile der Datei kodieren. Eine serverseitige QR-Erzeugung oder eine erneute Übertragung des Passworts an den Server SHALL dafür nicht erforderlich sein.

#### Scenario: QR und Datei stimmen überein

- **WHEN** auf der Once-Credentials-Seite der QR-Code dekodiert wird
- **THEN** entspricht sein Inhalt bytegleich der `tasmota_config.txt`

#### Scenario: Kein zusätzlicher Secret-Weg

- **WHEN** der QR-Code erzeugt wird
- **THEN** wird keine Netzwerk-Anfrage mit dem Passwort ausgelöst

### Requirement: Ungültige Backlog-Zeichen werden abgelehnt

Ein Passwort, das Zeichen enthält, welche die Tasmota-`Backlog`-Syntax brechen (mindestens `;`, Anführungszeichen, Backslash oder Zeilenumbruch), SHALL nicht in eine Config übernommen werden. Die Erzeugung SHALL abbrechen und einen verständlichen Hinweis ausgeben.

#### Scenario: Semikolon im Passwort

- **WHEN** das gewählte Passwort ein Semikolon enthält
- **THEN** wird keine Config erzeugt und der Benutzer erhält einen Hinweis auf das ungültige Zeichen

#### Scenario: Gültiges Passwort

- **WHEN** das Passwort keine Backlog-kritischen Zeichen enthält
- **THEN** erscheint es unverändert in der `Backlog0`-Zeile
