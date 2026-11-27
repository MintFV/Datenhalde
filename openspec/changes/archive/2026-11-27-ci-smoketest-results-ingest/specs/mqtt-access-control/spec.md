# Spec Delta

## MODIFIED Requirements

### Requirement: Der schreibende Broker-Dienst benötigt nur Lesezugriff

Der Benutzer des MQTT-zu-InfluxDB-Dienstes SHALL nur `read umweltbox/#` und `read smoketest/mintfv-smoketest/results/#` besitzen und SHALL keine Schreibberechtigung für MQTT-Topics haben.

#### Scenario: Node-RED empfängt weiterhin Daten

- **WHEN** `nodered-writer` von `readwrite #` auf `read umweltbox/#` reduziert wird
- **THEN** empfängt der bestehende `mqtt in`-Knoten weiterhin Nachrichten und schreibt sie unverändert nach InfluxDB

#### Scenario: Node-RED liest Smoketest-Ergebnisse

- **WHEN** `nodered-writer` zusätzlich `read smoketest/mintfv-smoketest/results/#` erhält
- **THEN** kann der Dienst Ergebnisnachrichten empfangen und besitzt weiterhin keine Schreibberechtigung für MQTT-Topics

### Requirement: Smoketest-Ergebnisse werden dauerhaft gespeichert

Der Smoketest SHALL Ergebnisse und Gesamtergebnis über MQTT veröffentlichen; Node-RED SHALL daraus Punkte in `mintfv`/`smoketest_results` speichern. Ein fehlgeschlagener Lauf SHALL vor dem Exit mit `ok=0` gespeichert werden. Die Punkte SHALL über MQTT und Node-RED entstehen, nicht durch direkten InfluxDB-Schreibzugriff. Jeder Punkt SHALL `source=prod` oder `source=ci` tragen.

#### Scenario: Erfolgreicher Lauf wird gespeichert

- **WHEN** alle Prüfungen des Smoketests erfolgreich sind
- **THEN** enthalten die gespeicherten Punkte je Prüfung und für das Gesamtergebnis `ok=1`, einen Zeitstempel und `source=prod`

#### Scenario: Fehlgeschlagener Lauf wird gespeichert

- **WHEN** eine Prüfung abweicht und der Smoketest deshalb abbricht
- **THEN** ist für die fehlgeschlagene Prüfung und das Gesamtergebnis `ok=0` gespeichert und der Exitcode ist von Null verschieden

#### Scenario: Round-Trip bleibt getrennt von den Ergebnissen

- **WHEN** der MQTT-Round-Trip im Test-Namespace läuft
- **THEN** entsteht kein Punkt im Measurement `sensors`, und die Ergebnispunkte werden ausschließlich über den Ergebnis-Topic und Node-RED gespeichert

#### Scenario: Keine Geheimnisse in den Ergebnissen

- **WHEN** Smoketest-Ergebnisse veröffentlicht und gespeichert werden
- **THEN** enthalten sie weder MQTT-Credentials noch InfluxDB-Tokens

#### Scenario: CI-Ergebnisse sind gekennzeichnet

- **WHEN** Ergebnisse aus der GitHub-Action über den MQTT-Ergebnis-Topic veröffentlicht werden
- **THEN** besitzen alle Punkte `source=ci` und die Kennung des auslösenden Workflow-Laufs

#### Scenario: Manuelle und CI-Läufe bleiben unterscheidbar

- **WHEN** InfluxDB Ergebnisse beider Herkünfte enthält
- **THEN** liefern Abfragen nach `source=prod` und `source=ci` jeweils nur die Punkte der entsprechenden Herkunft

#### Scenario: Ergebnisse bleiben im gescopten Topic

- **WHEN** die Testidentität Ergebnisse unter `smoketest/mintfv-smoketest/results/#` veröffentlicht
- **THEN** werden die Nachrichten angenommen und es wird weiterhin kein Topic unter `umweltbox/#` beschrieben
