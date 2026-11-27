# mqtt-access-control Specification

## Purpose

Diese Capability beschreibt, wie MQTT-Berechtigungen auf dem Broker vergeben, geprüft und geändert werden, damit Geräte und Dienste nur die Topics erreichen, die für ihre Aufgabe erforderlich sind, und damit Mandantendaten voneinander getrennt bleiben.

## Requirements

### Requirement: Gerätezugriff ist auf den eigenen Namespace beschränkt

Ein Gerätebenutzer SHALL ausschließlich `write umweltbox/{tenant}/{device}/#`, `read umweltbox/{tenant}/{device}/cmnd/#` und `read $SYS/broker/version` besitzen. Ungescopte Regeln wie `write #` oder `read #` SHALL für Gerätebenutzer nicht vorhanden sein.

#### Scenario: Referenzgerät behält seine Berechtigungen

- **WHEN** die ACL von `de-hh-mintfv-uwbox23` nach der Änderung gelesen wird
- **THEN** sind seine drei Regeln unverändert und der Datenfluss in InfluxDB bleibt bestehen

#### Scenario: Gerät mit Wildcard-Zugriff wird gescopt

- **WHEN** die Regeln von `de-hh-mintfv-uwbox02` durch das Muster von `de-hh-mintfv-uwbox23` ersetzt werden
- **THEN** darf dieser Benutzer nur noch unter `umweltbox/de-hh-mintfv-uwbox02/#` schreiben und unter `umweltbox/de-hh-mintfv-uwbox02/cmnd/#` lesen

### Requirement: Ungenutzte Broker-Identitäten werden entfernt

Eine Broker-Identität ohne bekannten Verwender SHALL weder in der ACL noch in der Passwortdatei vorhanden sein. Die Entfernung SHALL keine andere Identität oder deren Regeln verändern.

#### Scenario: mcp-admin-user wird entfernt

- **WHEN** `mcp-admin-user` aus ACL und Passwortdatei gelöscht wird
- **THEN** kann sich kein Client mehr mit dieser Identität anmelden und alle anderen Benutzer behalten ihre Regeln

### Requirement: Der schreibende Broker-Dienst benötigt nur Lesezugriff

Der Benutzer des MQTT-zu-InfluxDB-Dienstes SHALL nur `read umweltbox/#` besitzen und SHALL keine Schreibberechtigung für MQTT-Topics haben.

#### Scenario: Node-RED empfängt weiterhin Daten

- **WHEN** `nodered-writer` von `readwrite #` auf `read umweltbox/#` reduziert wird
- **THEN** empfängt der bestehende `mqtt in`-Knoten weiterhin Nachrichten und schreibt sie unverändert nach InfluxDB

### Requirement: ACL-Änderungen sind nachweisbar und rückholbar

Vor jeder ACL-Änderung SHALL eine wiederherstellbare Kopie der Datei existieren. Nach jeder Änderung SHALL der Broker die neue ACL wirksam laden und der unveränderte Datenfluss des Referenzgeräts SHALL verifiziert werden.

#### Scenario: Reload nach einer ACL-Änderung

- **WHEN** die geänderte ACL per SIGHUP neu geladen wird
- **THEN** zeigen die Broker-Logs weiterhin Verbindungen von `de-hh-mintfv-uwbox23` und InfluxDB weiterhin aktuelle Punkte aus dessen Topics

### Requirement: Die Testidentität ist eng gescopt

Die Testidentität `mintfv-smoketest` SHALL ausschließlich `write` und `read` auf `smoketest/mintfv-smoketest/#`, `read` auf `umweltbox/de-hh-mintfv-uwbox23/#` und `read $SYS/broker/version` besitzen. Sie SHALL keine Schreibberechtigung für `umweltbox/#` haben. Ihre Credentials SHALL nicht im Repo gespeichert sein.

#### Scenario: Round-Trip im Test-Namespace

- **WHEN** die Testidentität auf `smoketest/mintfv-smoketest/#` publiziert und abonniert
- **THEN** wird die Nachricht zugestellt und es wird kein Punkt in InfluxDB geschrieben

#### Scenario: Kein Zugriff auf Gerätetopics

- **WHEN** die Testidentität versucht, unter `umweltbox/de-hh-mintfv-uwbox23/#` zu schreiben
- **THEN** verweigert der Broker den Publish und der Smoketest meldet die Abweichung

### Requirement: Der Smoketest ist vor und nach jeder Änderung ausführbar

Ein einfacher Smoketest SHALL vor und nach jeder ACL-Änderung ausgeführt werden können. Er SHALL statische ACL-Regeln prüfen, einen MQTT-Round-Trip im Test-Namespace durchführen, den Canary `de-hh-mintfv-uwbox23` prüfen und aktuelle InfluxDB-Punkte nachweisen. Bei einer Abweichung SHALL er fehlschlagen.

#### Scenario: Baseline vor einer Änderung

- **WHEN** der Smoketest vor der ersten Änderung läuft
- **THEN** endet er erfolgreich und protokolliert den Referenzzustand

#### Scenario: Verifikation nach einer Änderung

- **WHEN** der Smoketest nach einer ACL-Änderung läuft
- **THEN** endet er erfolgreich, sofern uwbox23 unverändert Daten liefert und keine ungescopte Regel hinzugekommen ist

#### Scenario: Abweichung wird erkannt

- **WHEN** eine erwartete Regel fehlt oder InfluxDB keine aktuellen Punkte aus uwbox23-Topics liefert
- **THEN** meldet der Smoketest einen Fehler und bricht mit einem von Null verschiedenen Exitcode ab

### Requirement: Smoketest-Ergebnisse werden dauerhaft gespeichert

Der Smoketest SHALL das Ergebnis jeder Prüfung und ein Gesamtergebnis als Punkt in InfluxDB speichern. Ein fehlgeschlagener Lauf SHALL mit `ok=0` gespeichert werden, bevor das Skript mit einem von Null verschiedenen Exitcode endet. Die Punkte SHALL vom Smoketest selbst geschrieben werden und nicht über MQTT-Topics oder Node-RED entstehen.

#### Scenario: Erfolgreicher Lauf wird gespeichert

- **WHEN** alle Prüfungen des Smoketests erfolgreich sind
- **THEN** enthalten die gespeicherten Punkte je Prüfung und für das Gesamtergebnis `ok=1` und einen Zeitstempel

#### Scenario: Fehlgeschlagener Lauf wird gespeichert

- **WHEN** eine Prüfung abweicht und der Smoketest deshalb abbricht
- **THEN** ist für die fehlgeschlagene Prüfung und das Gesamtergebnis `ok=0` gespeichert und der Exitcode ist von Null verschieden

#### Scenario: Round-Trip bleibt getrennt von den Ergebnissen

- **WHEN** der MQTT-Round-Trip im Test-Namespace läuft
- **THEN** entsteht kein Punkt im Measurement `sensors`, und die Ergebnispunkte werden ausschließlich vom Smoketest geschrieben

#### Scenario: Keine Geheimnisse in den Ergebnissen

- **WHEN** Smoketest-Ergebnisse gespeichert und ausgegeben werden
- **THEN** enthalten sie weder MQTT-Credentials noch InfluxDB-Tokens

### Requirement: Die ACL-Datei ist nicht weltbeschreibbar

Die Datei `mosquitto/config/mosquitto.acl` SHALL für andere Benutzer nicht beschreibbar sein. Der Selfservice SHALL weiterhin schreiben und der Broker SHALL weiterhin lesen können.

#### Scenario: Rechte werden korrigiert

- **WHEN** Besitz und Modus der ACL-Datei so gesetzt werden, dass nur Eigentümer und Gruppe schreiben dürfen
- **THEN** kann der Selfservice die Datei weiterhin unter `flock` aktualisieren und Mosquitto kann sie lesen
