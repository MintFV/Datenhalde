# smoketest-result-publishing Specification

## Purpose

Diese Capability beschreibt, wie Smoketest-Ergebnisse aus manuellen Läufen und aus GitHub Actions über MQTT an die Produktion geliefert und dort in InfluxDB gespeichert werden, einschließlich Herkunft und Identität des auslösenden Laufs.

## Requirements

### Requirement: Smoketest-Ergebnisse werden über MQTT veröffentlicht

Der Smoketest SHALL jedes Ergebnis als Nachricht unter `smoketest/mintfv-smoketest/results/prod` veröffentlichen, wenn er auf `mintfv` läuft. Der CI-Workflow SHALL dieselben Ergebnisse unter `smoketest/mintfv-smoketest/results/ci` veröffentlichen. Beide Pfade SHALL dieselbe Nachrichtenstruktur verwenden.

#### Scenario: Manueller Lauf veröffentlicht Ergebnisse

- **WHEN** der Smoketest auf `mintfv` ausgeführt wird
- **THEN** werden die Ergebnisse unter `smoketest/mintfv-smoketest/results/prod` veröffentlicht

#### Scenario: CI-Lauf veröffentlicht Ergebnisse

- **WHEN** der GitHub-Workflow den Smoketest ausführt
- **THEN** werden die Ergebnisse unter `smoketest/mintfv-smoketest/results/ci` veröffentlicht

### Requirement: Herkunft und Laufidentität sind in der Nachricht enthalten

Jede Nachricht SHALL die Herkunft aus dem Topic-Suffix ableiten lassen. CI-Nachrichten SHALL zusätzlich `run_id`, `sha` und `ref` des Workflow-Laufs enthalten. Die Verarbeitung SHALL Nachrichten ohne diese Angaben verwerfen.

#### Scenario: CI-Nachricht enthält Laufkennung

- **WHEN** ein CI-Lauf Ergebnisse veröffentlicht
- **THEN** enthält die Nachricht `run_id`, `sha` und `ref` und wird als `source=ci` gespeichert

#### Scenario: Unvollständige Nachricht wird verworfen

- **WHEN** eine CI-Nachricht ohne `run_id` eintrifft
- **THEN** wird kein Punkt gespeichert

### Requirement: Verarbeitung schreibt nur gültige Ergebnispunkte

Die Verarbeitung SHALL Nachrichten nur akzeptieren, wenn `check` aus `acl`, `mqtt`, `canary` oder `overall` stammt und `ok` den Wert 0 oder 1 hat. `canary_count` SHALL nur beim Canary und als nicht-negative Ganzzahl vorkommen. Ungültige Nachrichten SHALL verworfen werden, ohne Punkte zu erzeugen.

#### Scenario: Gültige Nachricht wird gespeichert

- **WHEN** eine Nachricht mit zulässigem `check` und `ok` eintrifft
- **THEN** entsteht ein Punkt im Measurement `smoketest_results` mit dem Herkunftstag aus dem Topic

#### Scenario: Ungültige Nachricht wird verworfen

- **WHEN** eine Nachricht mit unbekanntem `check` oder unzulässigem `ok` eintrifft
- **THEN** entsteht kein Punkt und die Nachricht wird nicht weiterverarbeitet

### Requirement: Fehlschläge werden vollständig veröffentlicht

Wenn eine Prüfung fehlschlägt, SHALL die Nachricht `ok=0` für die betroffene Prüfung und für `overall` enthalten. Der ausführende Lauf SHALL anschließend mit einem von Null verschiedenen Exitcode enden.

#### Scenario: Fehlgeschlagener Lauf ist im Dashboard sichtbar

- **WHEN** eine Prüfung fehlschlägt
- **THEN** werden `ok=0` für die Prüfung und für `overall` veröffentlicht und gespeichert, und der Lauf meldet einen Fehler

### Requirement: Ergebnisse enthalten keine Geheimnisse und keine Sensordaten

Die veröffentlichten Nachrichten SHALL weder MQTT-Credentials noch InfluxDB-Tokens enthalten. Die Verarbeitung SHALL ausschließlich `smoketest_results` schreiben und SHALL keine Punkte in `sensors` erzeugen.

#### Scenario: Keine Geheimnisse in der Nachricht

- **WHEN** Ergebnisse veröffentlicht und verarbeitet werden
- **THEN** enthalten Nachrichten und gespeicherte Felder keine Zugangsdaten

#### Scenario: Sensordaten bleiben unberührt

- **WHEN** Smoketest-Ergebnisse verarbeitet werden
- **THEN** entsteht kein Punkt in `sensors` und es wird kein Topic unter `umweltbox/#` beschrieben
