# Spec Delta

## ADDED Requirements

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
