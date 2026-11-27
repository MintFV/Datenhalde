# Tasks

## 1. CI-Job

- [x] 1.1 Neuen Job `unit-tests` in `.github/workflows/ci.yml` ergänzen: Python 3.11 wie im Lint-Job, Installation von `selfservice/requirements-dev.txt`, Ausführung von `python -m pytest` mit `working-directory: selfservice` — Verifikation: YAML ist gültig und der Job enthält `python-version: '3.11'` sowie den pytest-Schritt
- [x] 1.2 Sicherstellen, dass der Job bei Push und Pull Request auf `refactorPED` läuft und kein `needs: lint` hat — Verifikation: Trigger-Block unverändert, der neue Job ist unabhängig vom Lint-Job
- [x] 1.3 `.github/README-CI.md` um den Job und den lokalen Befehl `cd selfservice && python -m pytest` ergänzen — Verifikation: dokumentierter Befehl ist im Repo ausführbar

## 2. Abnahme

- [x] 2.1 Lokal die Reihenfolge lint → typecheck → test ausführen — Verifikation: `ruff check selfservice`, `mypy --config-file selfservice/pyproject.toml selfservice` und `python -m pytest` aus `selfservice/` laufen ohne Fehler (44 passed)
- [x] 2.2 Prüfen, dass kein neues Secret und kein SSH-Zugriff eingeführt wurde — Verifikation: Suche im Workflow nach `secrets.`, `ssh` und Token-Namen bleibt ohne Treffer

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
