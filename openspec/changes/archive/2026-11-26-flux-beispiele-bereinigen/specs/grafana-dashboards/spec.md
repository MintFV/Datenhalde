# Spec Delta

## Purpose

Diese Capability beschreibt, wie Grafana-Dashboards in diesem Projekt bereitgestellt werden, damit sie von der InfluxDB-3-Core-Datasource geladen werden können und Abfragen in der von ihr unterstützten Sprache ausführen.

## ADDED Requirements

### Requirement: Provisionierte Dashboards verwenden SQL

Jede Datei unter `grafana/dashboards/` SHALL ihre Abfragen als SQL oder InfluxQL definieren. `queryType: flux` und `from(bucket: …)` SHALL in provisioningierten Dashboards nicht vorkommen.

#### Scenario: Keine Flux-Queries im Provisioning-Pfad

- **WHEN** alle Dashboard-Dateien nach der Änderung durchsucht werden
- **THEN** enthalten sie keine `queryType: flux` und keine `from(bucket: …)`-Ausdrücke mehr

#### Scenario: Abfragen laufen über die SQL-Datasource

- **WHEN** ein provisioniertes Dashboard geöffnet wird
- **THEN** zeigt das Grafana-Log ausgeführte SQL-Abfragen gegen die InfluxDB-Datasource und keine Flux-Fehler

### Requirement: Dashboard-Dateien sind provisioningfähig

Jede Dashboard-Datei SHALL einen nicht-leeren Titel und eine stabile UID auf der obersten Ebene besitzen, damit der Grafana-File-Provider sie laden kann.

#### Scenario: Provisioning ohne Fehler

- **WHEN** Grafana die Dashboard-Dateien beim Start und im 10-Sekunden-Intervall neu lädt
- **THEN** enthält das Log keine Meldung „Dashboard title cannot be empty"

#### Scenario: Dashboard ist geladen

- **WHEN** die Dashboards über die Grafana-API abgefragt werden
- **THEN** erscheint „mintfv - Umweltbox Übersicht" in der Liste der Dashboard-Dateien

### Requirement: Bestehende Panels bleiben funktional

Die Panels für Temperatur, Luftfeuchte und Taupunkt, die Tabelle „Latest values" sowie die Template-Variable für Tenants SHALL nach der Umstellung weiterhin Daten aus `sensors` liefern.

#### Scenario: Zeitreihen zeigen Messwerte

- **WHEN** das Dashboard mit einem ausgewählten Tenant geöffnet wird
- **THEN** liefern die drei Zeitreihen-Panels Messwerte aus der Tabelle `sensors`

#### Scenario: Tenant-Auswahl ist gefüllt

- **WHEN** die Template-Variable des Dashboards ausgewertet wird
- **THEN** listet sie die vorhandenen `tenant_id`-Werte aus `sensors` auf
