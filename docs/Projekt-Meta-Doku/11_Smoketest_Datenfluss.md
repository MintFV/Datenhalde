# Smoketest-Datenfluss

Dieses Diagramm zeigt, wie Smoketest-Ergebnisse von der GitHub-Action bzw. einem manuellen Lauf über MQTT und Node-RED in InfluxDB gelangen und im Grafana-Dashboard sichtbar werden. Es ergänzt die textliche Dokumentation in `10_Doku_Code_Abgleich_2026-11.md` und den archivierten OpenSpec-Change `ci-smoketest-results-ingest`.

```mermaid
flowchart TB
    subgraph A["Auslöser"]
        PUSH["Push auf refactorPED"]
        GH["GitHub-Action<br/>mqtt-smoke.yml<br/>isolierter Runner"]
        MAN["Manueller Lauf<br/>tests/mqtt-acl-smoke.sh<br/>auf mintfv"]
        PUSH --> GH
    end

    subgraph B["Prüfungen – beide Pfade"]
        ACL["1. Statische ACL<br/>mintfv-smoketest und uwbox23"]
        MQTT["2. MQTT-Round-Trip<br/>smoketest/mintfv-smoketest/ping"]
        CAN["3. InfluxDB-Canary<br/>sensors · uwbox23 · 30 min"]
        ACL --> MQTT --> CAN
    end

    subgraph C["Veröffentlichung"]
        RES["Ergebnisse je Prüfung<br/>acl · mqtt · canary · overall"]
        CI["Topic .../results/ci<br/>mit run_id, sha, ref"]
        PROD["Topic .../results/prod"]
        RES -->|"ci"| CI
        RES -->|"prod"| PROD
    end

    subgraph D["Verarbeitung auf mintfv"]
        ACLNR["Broker-ACL<br/>nodered-writer: read results/#<br/>keine Schreibrechte"]
        SUB["mqtt in<br/>smoketest/mintfv-smoketest/results/#"]
        FN["Function<br/>Validierung · source aus Topic<br/>Tags: source, run_id, sha, ref"]
        WRITE["HTTP POST<br/>api/v3/write_lp"]
        ACLNR -.->|"erlaubt"| SUB
        SUB --> FN --> WRITE
    end

    subgraph E["Persistenz und Sicht"]
        DB[("InfluxDB mintfv<br/>Measurement smoketest_results<br/>Felder: ok, canary_count")]
        DASH["Grafana mintfv-smoketest<br/>Variable source = prod oder ci<br/>CI-Panel für Runner-Läufe"]
        DB --> DASH
    end

    GH --> ACL
    MAN --> ACL
    CAN -->|"ok=1"| RES
    ACL -.->|"ok=0"| RES
    MQTT -.->|"ok=0"| RES
    CAN -.->|"ok=0"| RES
    CI --> SUB
    PROD --> SUB
    WRITE --> DB
```

## Legende

- **Auslöser:** Die GitHub-Action läuft bei jedem Push gegen einen isolierten Wegwerf-Stack auf dem Runner. Der manuelle Lauf läuft direkt auf `mintfv` gegen den Produktionsbroker.
- **Prüfungen:** beide Pfade prüfen die statischen ACL-Regeln, einen MQTT-Round-Trip im Test-Namespace und aktuelle InfluxDB-Punkte des Referenzgeräts `de-hh-mintfv-uwbox23`.
- **Herkunft:** `source=prod` bedeutet manueller Lauf auf `mintfv`; `source=ci` bedeutet isolierter Runner der GitHub-Action. **CI-Ergebnisse beschreiben nicht den Produktionszustand.**
- **Topic-Schema:** `smoketest/mintfv-smoketest/results/prod` bzw. `.../results/ci`. Die Identität `mintfv-smoketest` darf nur unter `smoketest/mintfv-smoketest/#` schreiben; `nodered-writer` darf das Ergebnis-Topic lesen und besitzt keine MQTT-Schreibrechte.
- **Datenhaltung:** Node-RED schreibt in die bestehende Datenbank `mintfv`, Measurement `smoketest_results`, mit den Feldern `ok` und `canary_count` sowie den Tags `check`, `source` und bei CI zusätzlich `run_id`, `sha`, `ref`.
- **Fehlerpfad (gestrichelt):** bei einer Abweichung werden `ok=0` für die betroffene Prüfung und für `overall` veröffentlicht; der Lauf endet mit einem von Null verschiedenen Exitcode.
- **Sichtbarkeit:** Das Dashboard `mintfv-smoketest` filtert über die Variable `source` (Default `prod`); ein eigenes Panel zeigt CI-Läufe mit `run_id`, `sha` und `ok`.
