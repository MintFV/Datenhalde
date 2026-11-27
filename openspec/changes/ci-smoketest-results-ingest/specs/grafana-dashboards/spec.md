# Spec Delta

## MODIFIED Requirements

### Requirement: Smoketest-Dashboard zeigt Ergebnisverlauf

Ein provisioningiertes Dashboard SHALL den Status des letzten Smoketest-Laufs sowie den Verlauf der Prüfungen ACL, MQTT-Round-Trip und InfluxDB-Canary aus InfluxDB anzeigen. Es SHALL dieselben Provisionierungs- und SQL-Regeln wie die übrigen Dashboards einhalten. Die Panels SHALL nach Herkunft der Läufe (`source=prod` oder `source=ci`) trennbar sein; ein CI-Panel SHALL Runner-Läufe gesondert ausweisen.

#### Scenario: Dashboard wird provisioniert

- **WHEN** Grafana die Dashboard-Dateien beim Start und im 10-Sekunden-Intervall neu lädt
- **THEN** erscheint das Smoketest-Dashboard mit nicht-leerem Titel und stabiler UID in der Dashboard-Liste

#### Scenario: Ergebnisse werden angezeigt

- **WHEN** Smoketest-Punkte der gewählten Herkunft in InfluxDB vorhanden sind
- **THEN** zeigt die Status-Karte das letzte Gesamtergebnis und die drei Zeitreihen den Wert jeder Prüfung über die Zeit

#### Scenario: Fehlschlag ist sichtbar

- **WHEN** ein Smoketest-Lauf fehlgeschlagen ist
- **THEN** ist dieser Lauf im Verlauf mit `ok=0` erkennbar

#### Scenario: Abfragen bleiben SQL

- **WHEN** die Panels des Smoketest-Dashboards ausgewertet werden
- **THEN** verwenden sie SQL-Abfragen gegen die vorhandene InfluxDB-Datasource und keine Flux-Queries

#### Scenario: Herkunft ist wählbar

- **WHEN** das Dashboard geöffnet wird
- **THEN** bietet eine Template-Variable `source` die Werte `prod` und `ci` an, ist auf `prod` voreingestellt und filtern alle Status- und Verlaufs-Panels auf den gewählten Wert

#### Scenario: CI-Läufe sind gesondert sichtbar

- **WHEN** CI-Ergebnisse in InfluxDB vorhanden sind und das Dashboard mit der Voreinstellung geöffnet wird
- **THEN** zeigt das CI-Panel die letzten Runner-Läufe mit `run_id` und `ok`, während die übrigen Panels weiterhin manuelle Läufe anzeigen

#### Scenario: Herkunft ist im Titel erkennbar

- **WHEN** die Herkunft im Dashboard gewechselt wird
- **THEN** benennt der Titel der Status-Karte die gewählte Herkunft, sodass CI-Ergebnisse nicht als Produktionszustand gelesen werden
