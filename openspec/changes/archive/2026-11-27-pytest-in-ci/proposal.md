# Proposal

## Why

`selfservice/tests` enthält 44 Unit-Tests, die CI führt aber nur `ruff`, `mypy` und einen Playwright-Smoke aus. Änderungen an ACL-, Mail- oder Tenant-Logik können daher grün sein, obwohl die Unit-Tests fehlschlagen. Die nötigen Abhängigkeiten (`pytest`, `pytest-flask`) sind bereits in `requirements-dev.txt` enthalten.

## What Changes

- Neuer Job `unit-tests` in `.github/workflows/ci.yml`: Python 3.11 (wie der bestehende Lint-Job), Installation von `selfservice/requirements-dev.txt`, Ausführung von `python -m pytest` mit Arbeitsverzeichnis `selfservice`.
- Der Job läuft bei Push und Pull Request auf `refactorPED` und ist unabhängig vom Lint-Job, damit ein Fehler direkt sichtbar wird.
- `.github/README-CI.md` beschreibt den Job und den lokalen Befehl `cd selfservice && python -m pytest`.
- Keine neuen Secrets, kein Coverage-Threshold und keine Änderung an `pyproject.toml`: die Abweichung „CI py311 / Target py312" bleibt bewusst bestehen und wird nicht in diesem Change gelöst.

## Capabilities

### New Capabilities

- `ci-quality-gates`: welche automatisierten Prüfungen ein Push oder Pull Request auf dem Entwicklungsbranch bestehen muss.

### Modified Capabilities

- keine

## Impact

- Geändert: `.github/workflows/ci.yml`, `.github/README-CI.md`.
- Neu: `openspec/specs/ci-quality-gates/spec.md` und die Change-Artefakte.
- Unverändert: Anwendungscode, Datenbank, Secrets, Produktion und die Python-Zielversion in `pyproject.toml`.
