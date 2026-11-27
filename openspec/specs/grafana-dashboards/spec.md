# grafana-dashboards Specification

## Purpose

Diese Capability beschreibt, wie Grafana-Dashboards in diesem Projekt bereitgestellt werden, damit sie von der InfluxDB-3-Core-Datasource geladen werden können und Abfragen in der von ihr unterstützten Sprache ausführen.

## Requirements

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
