# Spec Delta

## Purpose

Diese Capability beschreibt, welche automatisierten Prüfungen ein Push oder Pull Request auf dem Entwicklungsbranch bestehen muss, damit regressionsfähige Änderungen nicht unbemerkt in den Branch gelangen.

## ADDED Requirements

### Requirement: Unit-Tests laufen bei jedem Push und Pull Request

Die CI SHALL die Unit-Tests des Selfservice bei jedem Push und bei jedem Pull Request auf `refactorPED` ausführen. Ein Fehlschlag der Unit-Tests SHALL den CI-Lauf als fehlgeschlagen markieren.

#### Scenario: Push löst Unit-Tests aus

- **WHEN** ein Push auf `refactorPED` erfolgt
- **THEN** führt die CI die Unit-Tests des Selfservice aus und meldet deren Ergebnis

#### Scenario: Pull Request löst Unit-Tests aus

- **WHEN** ein Pull Request auf `refactorPED` geöffnet oder aktualisiert wird
- **THEN** führt die CI die Unit-Tests des Selfservice aus

#### Scenario: Fehlgeschlagener Test macht CI rot

- **WHEN** mindestens ein Unit-Test fehlschlägt
- **THEN** ist der CI-Lauf fehlgeschlagen

### Requirement: Unit-Tests verwenden dieselbe Python-Version wie der Lint-Job

Der Unit-Test-Job SHALL dieselbe Python-Version wie der bestehende Lint-Job verwenden. Eine Änderung der Python-Version SHALL beide Jobs gemeinsam betreffen.

#### Scenario: Versionen stimmen überein

- **WHEN** die Workflow-Datei der CI geprüft wird
- **THEN** verwenden der Lint-Job und der Unit-Test-Job dieselbe Python-Version

#### Scenario: Umstellung betrifft beide Jobs

- **WHEN** die CI auf eine andere Python-Version umgestellt wird
- **THEN** sind Lint- und Unit-Test-Job beide auf die neue Version gesetzt

### Requirement: Unit-Tests sind lokal reproduzierbar

Die Dokumentation SHALL einen Befehl enthalten, mit dem die Unit-Tests lokal mit derselben Konfiguration wie in der CI ausgeführt werden können. Der Befehl SHALL ohne zusätzliche Secrets oder Dienste funktionieren.

#### Scenario: Lokaler Lauf entspricht der CI

- **WHEN** der dokumentierte Befehl im Repo ausgeführt wird
- **THEN** werden dieselben Unit-Tests wie in der CI ausgeführt und bestanden

#### Scenario: Keine externen Voraussetzungen

- **WHEN** die Unit-Tests lokal ausgeführt werden
- **THEN** sind keine GitHub-Secrets, keine Datenbank und keine laufenden Dienste erforderlich
