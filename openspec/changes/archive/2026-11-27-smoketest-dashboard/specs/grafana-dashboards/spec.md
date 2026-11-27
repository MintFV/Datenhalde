# Spec Delta

## ADDED Requirements

### Requirement: Smoketest-Dashboard zeigt Ergebnisverlauf

Ein provisioningiertes Dashboard SHALL den Status des letzten Smoketest-Laufs sowie den Verlauf der Prüfungen ACL, MQTT-Round-Trip und InfluxDB-Canary aus InfluxDB anzeigen. Es SHALL dieselben Provisionierungs- und SQL-Regeln wie die übrigen Dashboards einhalten.

#### Scenario: Dashboard wird provisioniert

- **WHEN** Grafana die Dashboard-Dateien beim Start und im 10-Sekunden-Intervall neu lädt
- **THEN** erscheint das Smoketest-Dashboard mit nicht-leerem Titel und stabiler UID in der Dashboard-Liste

#### Scenario: Ergebnisse werden angezeigt

- **WHEN** Smoketest-Punkte in InfluxDB vorhanden sind
- **THEN** zeigt die Status-Karte das letzte Gesamtergebnis und die drei Zeitreihen den Wert jeder Prüfung über die Zeit

#### Scenario: Fehlschlag ist sichtbar

- **WHEN** ein Smoketest-Lauf fehlgeschlagen ist
- **THEN** ist dieser Lauf im Verlauf mit `ok=0` erkennbar

#### Scenario: Abfragen bleiben SQL

- **WHEN** die Panels des Smoketest-Dashboards ausgewertet werden
- **THEN** verwenden sie SQL-Abfragen gegen die vorhandene InfluxDB-Datasource und keine Flux-Queries
