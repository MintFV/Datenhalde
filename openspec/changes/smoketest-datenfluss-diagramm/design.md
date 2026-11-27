# Design

## Context

Siehe `proposal.md` für die Motivation. Der Change `ci-smoketest-results-ingest` ist archiviert; danach veröffentlicht das Skript Ergebnisse per MQTT, Node-RED schreibt sie mit `source=prod|ci` nach `smoketest_results`, und das Dashboard `mintfv-smoketest` trennt die Herkunft. Die Fakten liegen in `tests/mqtt-acl-smoke.sh`, `.github/workflows/mqtt-smoke.yml`, `nodered/data/flows.json`, `grafana/dashboards/mintfv-smoketest.json` und im archivierten Design. Es gibt noch keine zusammenhängende visuelle Darstellung.

## Goals / Non-Goals

**Goals:**

- Ein Diagramm, das beide Triggerpfade und den gemeinsamen Verarbeitungspfad zeigt.
- Fachlich korrekte Namen für Topics, Measurement, Tags und Dashboard-UID.
- Textbasierte, versionierbare Darstellung ohne externe Bilddatei.

**Non-Goals:**

- Kein Sequence-Diagramm mit Zeitachse und kein Zustandsdiagramm.
- Keine vollständige MintFV-Gesamtarchitektur und kein Netzwerk-/Portplan.
- Keine Änderung an Code, Compose-Dateien oder Diensten; kein Deploy.

## Decisions

**1. Ein Flowchart mit Subgraphs statt mehrerer Einzelbilder.** Ein `flowchart LR` mit Bereichen für „Auslöser", „Verarbeitung auf mintfv" und „Sichtbarkeit" zeigt Gemeinsamkeiten und Unterschiede der beiden Pfade direkt. Ein Sequence-Diagramm würde den Nachrichtenverlauf besser, aber die Rollen und das Topic-Schema schlechter zeigen; es ist daher nicht Teil dieses Changes.

**2. Mermaid direkt in Markdown.** GitHub und GitLab rendern ```mermaid-Blöcke nativ; es braucht kein Bild, kein Render-Artefakt und kein zusätzliches Tool im Repo. Alternative ein fertiges SVG/PNG verworfen: nicht ohne weiteres im Text diffbar und bei Änderungen aufwendiger zu pflegen.

**3. Fachliche Ebene statt Implementierungsdetails.** Das Diagramm nennt Dateien, Topics, Measurement, Tags und UID, aber keine Container-Flags, UIDs/GIDs oder Token-Werte. Ein Fehlschlag wird als gestrichelte Kante mit `ok=0` dargestellt. Die Herkunft kommt aus dem Topic-Suffix und wird in einer Legende erläutert.

**4. Ablage und Auffindbarkeit.** Die Datei heißt `11_Smoketest_Datenfluss.md` und schließt an die bestehende Nummerierung unter `docs/Projekt-Meta-Doku/` an. Ein Verweis aus anderen READMEs wird zunächst nicht ergänzt; die Datei ist über die Doku-Liste auffindbar. Das hält den Change auf eine Datei begrenzt.

## Risks / Trade-offs

- [Mermaid-Rendering unterscheidet sich zwischen GitHub/GitLab] → nur einfache Knoten- und Kanten-Syntax verwenden; keine HTML oder komplexe Styles.
- [Diagramm kann zu Code driftieren] → Legende enthält die stabilen Namen (Topic, Measurement, UID); bei Änderungen am Smoketest-Pfad wird die Datei mitgeändert.
- [Leser verwechselt `source=ci` mit Produktionszustand] → Node- und Kantenbeschriftung nennen explizit „isolierter Runner".

## Migration Plan

1. Datei mit Beschreibung, Mermaid-Block und Legende anlegen.
2. Syntax und Fachabgleich gegen die genannten Quelldateien prüfen.
3. Kein Rollback nötig; die Datei kann bei Bedarf einzeln zurückgesetzt werden.

## Open Questions

- Ob das Diagramm später in eine übergreifende Architekturseite eingebunden wird, ist eine Doku-Frage und verändert diesen Change nicht.
