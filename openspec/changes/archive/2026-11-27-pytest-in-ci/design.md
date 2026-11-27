# Design

## Context

Siehe `proposal.md` für die Motivation. `.github/workflows/ci.yml` hat heute die Jobs `lint` (Python 3.11, ruff/mypy) und `node-smoke` (Playwright, `needs: lint`). `selfservice/requirements-dev.txt` enthält bereits `pytest` und `pytest-flask`; `pyproject.toml` definiert `testpaths = ["tests"]` und zielt mit Ruff/mypy auf py312. Die Unit-Tests nutzen eine In-Memory-SQLite und setzen ihr Secret in `conftest.py`; eine echte Datenbank oder GitHub-Secrets brauchen sie nicht.

## Goals / Non-Goals

**Goals:**

- Unit-Tests als eigenes, sichtbares Qualitätsgate auf `refactorPED`.
- Lokal mit exakt demselben Befehl nachvollziehbar.
- Bestehende Jobs und Python-Version unverändert lassen.

**Non-Goals:**

- Keine Coverage-Pflicht, keine Benchmarks und keine neuen Dienste.
- Keine Anhebung der CI auf Python 3.12 und keine Änderung an `pyproject.toml`.
- Keine Änderung am Playwright-Smoke oder an `mqtt-smoke.yml`.

## Decisions

**1. Eigener Job parallel zum Lint-Job.** Ein separater Job `unit-tests` ohne `needs: lint` gibt unabhängiges Feedback und verhindert, dass ein Lint-Fehler die Unit-Tests verdeckt. Alternative, die Tests in den Lint-Job zu integrieren, wurde verworfen: ein gemeinsamer Job macht die Fehlerursache schwerer erkennbar und verhindert parallele Ausführung.

**2. Python 3.11 wie im Lint-Job.** `AGENTS.md` weist darauf hin, dass CI 3.11 nutzt, während `pyproject.toml` py312 targetet und 3.12-Syntax nicht blind verwendet werden soll. Solange die Tests auf 3.11 laufen, bleibt das Gate kompatibel mit dem bestehenden Job. Eine gemeinsame Umstellung auf 3.12 ist ein eigenes, späteres Thema.

**3. `python -m pytest` aus dem Verzeichnis `selfservice`.** Damit greift die `pytest`-Konfiguration aus `pyproject.toml` automatisch; zusätzliche Kommandozeilen-Flags oder eine eigene `pytest.ini` sind nicht nötig. Alternative, Tests vom Repo-Root mit Pfadargument zu starten, wurde verworfen: sie erzeugt eine andere Rootdir-Erkennung.

**4. Keine Coverage-Gate in diesem Change.** Die Tests laufen zu lassen ist der kleinste Schritt mit unmittelbarem Nutzen. Ein Mindest-Coverage-Wert würde eine Baseline-Messung und einen separaten Entscheidungsprozess erfordern.

## Risks / Trade-offs

- [Testlauf könnte durch fehlende Umgebung variieren] → `conftest.py` setzt `SECRET_KEY` und nutzt In-Memory-SQLite; der lokale Lauf ist in der Abnahme zu prüfen.
- [Python-Version bleibt inkonsistent zum pyproject-Target] → bewusst akzeptiert; als offenes Thema dokumentiert, nicht in diesem Change gelöst.
- [Zusätzlicher Job erhöht CI-Minuten] → 44 In-Memory-Tests sind kurz; kein eigenes Docker-Image nötig.

## Migration Plan

1. Job in `ci.yml` ergänzen und `.github/README-CI.md` aktualisieren.
2. Lokal lint → typecheck → pytest ausführen (Reihenfolge gemäß `AGENTS.md`).
3. Nach dem Push prüfen, dass der neue Job auf `refactorPED` grün ist.
4. Rollback: Job und Doku-Zeilen entfernen; keine Daten- oder Produktionswirkung.

## Open Questions

- Ob Lint- und Unit-Test-Job später gemeinsam auf Python 3.12 umgestellt werden, ist ein eigenes Thema und verändert diesen Change nicht.
