# Design

## Context

Siehe `proposal.md` für die Motivation. Die Changes `ci-smoketest-results-ingest` und `smoketest-datenfluss-diagramm` sind archiviert; ihre Fakten stehen in Code, Specs und `11_Smoketest_Datenfluss.md`, aber nicht im autoritativen Abgleich. `.github/README-CI.md` stammt aus der Zeit vor dem MQTT-Ingest. `AGENTS.md` enthält bereits die Regeln zu GitHub-Account und Commits, aber keine Secret-Ausnahme.

## Goals / Non-Goals

**Goals:**

- Doku und Betriebsregeln auf den verifizierten Ist-Stand bringen.
- Die Secret-Ausnahme so eng fassen, dass sie nicht als Freibrief für weitere Secrets verstanden wird.
- Wiedervorlage für spätere Agenten schaffen, ohne Handoff-Prompts aufzublähen.

**Non-Goals:**

- Kein Umschreiben historischer Nachträge und keine Änderung an Specs.
- Keine Secret-Werte, keine Token-Ausgabe und keine Reconfiguration von Diensten.

## Decisions

**1. Chronologischer Nachtrag statt Bearbeitung alter Abschnitte.** `10_Doku_Code_Abgleich_2026-11.md` führt Nachträge mit Datum; ein neuer Abschnitt „Nachtrag 2026-11-27" erhält die aktuellen Fakten und einen Verweis auf Diagramm und archivierte Changes. Das bewahrt die Historie und entspricht der bestehenden Struktur.

**2. Secret-Regel als eng gefasste Ausnahme in `AGENTS.md`.** Die Regel nennt exakt die zwei Variablennamen, die Identität `mintfv-smoketest` und deren Topic-Grenze. Ein generischer Satz wie „Secrets sind jetzt erlaubt" wurde verworfen, weil er künftige Entscheidungen zu Unrecht präjudizieren würde. Die dauerhafte Regel gehört in `AGENTS.md`, nicht in einen Handoff-Prompt.

**3. README-CI nur korrigieren, nicht neu schreiben.** Die vorhandene Beschreibung des `MQTT ACL smoke`-Workflows wird um die drei falschen Aussagen bereinigt. Die übrigen Abschnitte (Dependabot, E2E,.required Secrets) bleiben unverändert.

**4. Keine Duplizierung des Diagramms.** Der Nachtrag verweist auf `11_Smoketest_Datenfluss.md`; die Fakten werden in Kurzform wiederholt, damit der Abgleich auch ohne die zweite Datei verständlich bleibt.

## Risks / Trade-offs

- [Doku kann erneut driftieren] → Nachtrag nennt stabile Namen (Topic, UID, Workflow-Datei); bei künftigen Smoketest-Änderungen wird er mitgezogen.
- [Secret-Ausnahme könnte zu weit gelesen werden] → Formulierung nennt ausschließlich die zwei vorhandenen Secrets und verweist für alle anderen auf Rückfrage.
- [README-CI enthält weitere veraltete Angaben] → in diesem Change nur die betroffenen Zeilen korrigieren; weiterhin als eigenes Thema behandeln.

## Migration Plan

1. Drei Dateien entsprechend ändern und gegen die archivierten Changes gegenlesen.
2. Prüfen, dass keine Secret-Werte oder Tokens in den Doku-Dateien auftauchen.
3. Kein Rollback-Deploy nötig; die Änderungen sind reine Textdateien.

## Open Questions

- Ob die Secret-Ausnahme auch in die übergeordnete `/Users/petersa/git/AGENTS.md` gehört, ist eine Frage der Reichweite; dieser Change beschränkt sich auf das Projekt.
