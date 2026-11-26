# Doku–Code-Abgleich & Selfservice-Fachlichkeiten (Stand 2026-11-19)

## 0. Methode und Scope

Verglichen wurden:

- **Code:** kompletter `selfservice/`-App (Routes, Forms, Models, Service, Templates, Migration, Tests), `docker-compose.yaml`, nginx-/mosquitto-Configs, Helper-Skripte, CI-Workflows.
- **Doku:** `README.md`, `AGENTS.md`, `BACKUP.md`, `selfservice/README.md`, `docs/Projekt-Meta-Doku/01–09`, `docs/TASMOTA_SETUP.md`, Service-READMEs, `.github/*.md`, `env.example`, `blue-team-audit/` (lokal, gitignoriert).
- **Produktive Laufzeit:** `mintfv.peddy.net` (read-only via `mintfv.peddy.net`-Zugang), `docker ps`, Git-Status, SQLite-DB, mosquitto.acl, nginx-Config, laufender Container.

**Quelle der Wahrheit ist der Code bzw. die produktive Laufzeit, nicht die Doku.** Die Meta-Doku (01–09) ist überwiegend ein *Zielbild* aus Januar 2026 und wurde seither nur punktuell (InfluxDB-3-Hinweise) nachgezogen.

---

## 1. Gesamturteil

| Bereich | Bewertung |
|---|---|
| Infrastruktur-Doku (README, compose, UIDs, Ports, Security) | **weitgehend konsistent** |
| Selfservice-README | **teilweise veraltet** (Rate-Limits, Image, Routen, Defaults, Frontend) |
| MQTT-ACL-/Topic-Doku (03) vs. Implementierung | **deutliche Drift** (Rollen, Topic-Namen, $SYS) |
| Onboarding-/Architektur-Doku (02, 05, 09) vs. Code | **Zielbild, nicht Realität** – große Lücke |
| Produktive Laufzeit vs. Git | CSS-Stand war uncommitted und live → **inzwischen nachgezogen** (Commit `16a4b9b`); Produktion liegt damit einen Commit zurück |

**Kurzfassung:** Die Plattform-Infrastruktur ist gut dokumentiert und deckt sich mit dem Compose-Stack. Der Selfservice ist funktional deutlich kleiner als in der Meta-Doku beschrieben: Es gibt Registrierung/Login/Passwort-Reset und eine MQTT-Account-CRUD – aber **keinen** Tenant-/Device-/Onboarding-/Config-Download-/Monitoring-/Admin-Flow. In Produktion wird die MQTT-Verwaltung überhaupt nicht genutzt (0 Tenants, 0 Accounts, 0 Devices); ACLs werden manuell gepflegt.

---

## 2. Detaillierte Abweichungen

### 2.1 Selfservice-README (`selfservice/README.md`)

| ID | Schwere | Doku-Aussage | Code / Realität | Beleg |
|---|---|---|---|---|
| D1 | hoch | Rate-Limits: Registrierung 3/h, Login 5/min, Reset 3/h, Resend 3/h, Passwort 5/h (Z. 120–126) | `109/hour` bzw. `109/minute`; global zusätzlich `60/minute` | `app/auth/routes.py:85,130,202,264,293`; `app/extensions.py:35` |
| D2 | mittel | MQTT-Passwort-Änderung: `/selfservice/mqtt/<id>/passwort-aendern` (Z. 117) | Route ist `/selfservice/mqtt/<int:account_id>/passwort` | `app/mqtt/routes.py:153` |
| D3 | mittel | Image `python:3.12-slim` (Z. 6, 38) | `python:3.12-alpine` in beiden Stages | `Dockerfile:2,22` |
| D4 | niedrig | `DOMAIN`-Default `mintfv.example.com` (Z. 86) | Default `localhost` | `app/config.py:10` |
| D5 | niedrig | `SMTP_FROM`-Default `${SMTP_USER_PROVIDER}` (Z. 89) | Default `noreply@localhost` (bzw. `noreply@{DOMAIN}`) | `app/config.py:17-19,24` |
| D6 | niedrig | Benutzer-Hashing `pbkdf2:sha256` (Z. 153) | `generate_password_hash()` ohne Verfahrensangabe → Werkzeug-Default (nicht gepinnt) | `app/models.py:3,31-35` |
| D7 | ~~mittel~~ **erledigt** | Frontend: Grün `#2e7d32`, `max-width 1100px` (Z. 133, 138) | Live-CSS nutzt `#1b5e20`, Dark Mode, Container Queries, `1400–2200px`, Touch-Targets, Fluid Typography | Stand von Production übernommen und als `16a4b9b` committet; `selfservice/README.md` entsprechend korrigiert |
| D8 | mittel | MQTT-Account-Verwaltung als Funktion beschrieben (Z. 114–118) | Code existiert, aber ohne Tenant/Device ist sie nicht bedienbar; UI sagt „Tenant-Verwaltung … zukünftige Version“ | `app/mqtt/routes.py:63-71,86-88`; `templates/dashboard/overview.html:28` |

### 2.2 MQTT / ACL / Topics

| ID | Schwere | Doku-Aussage | Code / Realität | Beleg |
|---|---|---|---|---|
| D9 | **hoch** | Sensor-Rolle: `write umweltbox/{tenant}/{device}/#`, `read .../cmnd/{device}/#` (`03:243-249`, `service.py:182-186`) | Web-Flow übergibt **nie** `device_id`; jeder „Sensor“ landet im Else-Fallback `readwrite umweltbox/{tenant}/{username}/#`. Vom Audit als „Hohes Risiko: MQTT-ACL Fallback“ geführt. | `app/mqtt/routes.py:116-121`; `app/mqtt/service.py:204-211`; `blue-team-audit/REPORT…md` |
| D10 | mittel | `commands/{device}` (`03:248`, `02:101`) | Code verwendet `cmnd/{device}` (Tasmota-Konvention) | `app/mqtt/service.py:206` |
| D11 | mittel | `topic read $SYS/#` für Admin/Node-RED (`03:240,256`); Rolle `nodered` beschrieben (`03:251-257`, `models.py:106`) | Code gewährt nur `$SYS/broker/version`; `nodered` ist nur Kommentar, nicht im Formular und nicht in `add_acl_rules` | `app/mqtt/service.py:203,207,211`; `app/mqtt/forms.py:29-32` |
| D12 | mittel | Templates zeigen `umweltbox/{tenant}/#` für alle Rollen; Dashboard-Topic ohne `umweltbox/`-Präfix | ACL gewährt je nach Rolle andere Topics; angezeigtes Topic entspricht nicht der Realzahl | `app/dashboard/routes.py:7-11`; `templates/mqtt/credentials.html:36`; `templates/mqtt/overview.html`, `create.html` |

### 2.3 Meta-Doku (Zielbild vs. Ist)

| ID | Schwere | Doku-Aussage | Code / Realität | Beleg |
|---|---|---|---|---|
| D13 | **hoch** | Onboarding-Portal `/onboarding` mit Schuldaten-Formular, Auto-Approval, Tenant-ID-Generierung, Influx-/Grafana-Credentials, Config-Downloads (Tasmota/RPi/Telegraf), Live-Monitoring | **Nichts davon implementiert.** nginx kennt kein `/onboarding` und kein `/downloads`; keine Routen, keine Views. Produktion: 0 Tenants. | `docs/…/05_Onboarding_Prozess.md:38,45-63,69-71,116-125,127-193,248-254`; `nginx/conf.d/02-ssl.conf` |
| D14 | **hoch** | InfluxDB v2-API (`/api/v2/buckets`, `influx auth create`, Retention), Flux-Queries, `influx backup` | Stack läuft **InfluxDB 3 Core 3.8.0** (Port 8181, kein Web-UI): kein Flux, keine v2-Buckets-API; SQL/InfluxQL + `influxdb3`-CLI. `09` warnt korrekt, `02`/`05` nicht nachgezogen. | `docs/…/05:88-96,272-278,305`; `docs/…/02:73-74`; `docs/…/09:14`; `docker-compose.yaml` |
| D15 | mittel | „Onboarding-Portal“, „Admin-Interface“, „REST API Public Data Access“ als Komponenten | Nicht vorhanden. Selfservice hat nur Auth + (theoretische) MQTT-CRUD. | `docs/…/02:28-31,44-47,164-172` |
| D16 | niedrig | Audit-Status „Phase 1/3, Inventarisierung in Arbeit“ | 12 Interim-Dateien + konsolidierter Report liegen vor (lokal, gitignoriert) | `blue-team-audit/README.md:38-41`, `MASTERPLAN.md:276-278`, `REPORT…md` |

### 2.5 Infrastruktur / Skripte / CI (ergänzende Funde)

| ID | Schwere | Doku-/Skript-Aussage | Code / Realität | Beleg |
|---|---|---|---|---|
| D18 | hoch | „InfluxDB Admin Token wird automatisch beim ersten Start generiert“ | **Falsch.** Es gibt keinen Init, der `influxdb/tokens/admin.token` erzeugt; die Datei ist gitignoriert. Ein frischer Checkout kann `influxdb` nicht starten. | `env.example:96-99`; `docker-compose.yaml:356,361`; `.gitignore:45` |
| D19 | mittel | `curl … /influxdb/health` als validierter Health-Check | nginx-proxt `/influxdb/` **ohne Prefix-Strip** nach `http://influxdb:8181` → `/influxdb/health` wird 404. Die Playwright-Suite umgeht das bewusst und testet direkt `:8181`. | `nginx/conf.d/02-ssl.conf:150-162`; `tests/specs/influxdb.spec.ts:5-13`; `validate.sh:48`; `influxdb/README.md:158` |
| D20 | mittel | Grafana „Public Links (ohne Login)“, „Public Read-Only“ | `GF_AUTH_ANONYMOUS_ENABLED=false`; `grafana_auto_share.sh` existiert, um das manuell zu ändern | `docs/…/02:162,189`; `docker-compose.yaml:240`; `grafana_auto_share.sh:3-4` |
| D21 | mittel | „Sobald nginx läuft, holt Certbot automatisch ein echtes Zertifikat“; `mintfv.sh start` erstellt Dummy-Zert | `certbot` führt nur `renew` aus, kein initiales `certonly`; Dummy-Zert nur in `init`, nicht in `start`. Realer Weg: `./mintfv.sh request-cert`. | `README.md:66`; `certbot/SSL-SETUP.md:32-39`; `docker-compose.yaml:174-189`; `mintfv.sh:88-107,109-150,233-241` |
| D22 | mittel | `validate.sh` prüft Grafana mit `admin:admin` | Compose-Default ist `admingrafana` + Passwort aus Env | `validate.sh:38`; `docker-compose.yaml:238-239` |
| D23 | mittel | Externer MQTT-Zugang über `mintfv.peddy.net:1883` | Host publish nur **8883**; 1883/9001 sind `expose`-only und TLS-terminiert bei nginx | `nodered/README.md:113`; `mosquitto/README.md:87`; `docker-compose.yaml:99-102,408-410`; `nginx/stream.d/mqtt.conf:12-17` |
| D24 | mittel | `settings.js`-Kommentar: „LOADED FROM ENVIRONMENT!“ | `credentialSecret` ist literal im File enthalten; `NODE_RED_CREDENTIAL_SECRET` wird nie gelesen | `nodered/data/settings.js:24`; `docker-compose.yaml:491` |
| D25 | mittel | Drei konkurrierende ACL-Schemata: `commands/{dev}` (Doku), `cmnd/{dev}` (Python-Service), `umweltbox/de-hh-privat-peddy/{user}/commands/…` (Shell-Skript) | Dazu Live-ACL mit teils `tenant/…`, teils `umweltbox/…`. Kein einheitliches Modell. | `manage_mqtt_users.sh:61-70`; `app/mqtt/service.py:206`; `docs/…/03:248`; Produktion `mosquitto.acl` |
| D26 | niedrig | `mintfv.sh` verweist auf `config.yaml`, `nginx/conf/ssl.conf*`, `enable/disable-ssl` | Diese Dateien existieren nicht; SSL-Config ist immer `nginx/conf.d/02-ssl.conf`. Die Befehle sind wirkungslos. | `mintfv.sh:201-227,541`; `nginx/conf.d/` |
| D27 | niedrig | Stale Referenzen `mintfv.local`, hartcodierte Netzwerk-Namen `mintfv_mintfv-network`, `test_mqtt_pipeline_5levels.sh` | Compose-Projekt heißt in diesem Checkout `datenhalde` → Netz `datenhalde_mintfv-network`; Datei fehlt. | `setup_nodered_mqtt_user.sh:107`; `test_mqtt_pipeline.sh:611-612`; `tests/run-tests.sh:21`; `mintfv.sh:466` |
| D28 | niedrig | CI/E2E als „Full-Stack-Test“ | Playwright-`smoke` ist selbst-contained (`page.setContent`), testet den nginx-Container nicht; `e2e.yml` startet nur 8 Services und prüft Port 8080/:3000, die compose nicht published. | `tests/specs/smoke.spec.ts:3-7`; `.github/workflows/e2e.yml:18-26,38`; `ci.yml:91-93` |

**Positiv:** Alle Images in `docker-compose.yaml` sind auf konkrete Versionen gepinnt (kein `:latest`). Die Service-Tabelle in `README.md:5-26` ist vollständig (13 Services inkl. `certbot-init`; 12 davon laufen dauerhaft). UIDs, GID 2100, `read_only`+`tmpfs`, `cap_drop: ALL`, `no-new-privileges`, Healthchecks und `depends_on` entsprechen `AGENTS.md`.

### 2.6 Dokumentinterne Widersprüche (ohne Code-Bezug)

- **Status-Kennzeichnung fehlt:** `01:98` erklärt die Meta-Doku ausdrücklich als „Konzeptphase"; `02`, `05`, `09` lesen sich aber wie Ist-Beschreibungen. Daher stammen viele Drifts (D13–D15) daher, dass *Ziel* und *Realität* nicht gekennzeichnet sind. Empfehlung: klare Status-Banner („ZIELBILD – nicht implementiert") in 02/05/07/09.
- **InfluxDB-Datenbankname:** `grafana/README.md:58,99` → `mintfv`; `influxdb/README.md:56,179,188` → `mydb`; Meta-Doku → Buckets `umweltbox*`. Drei Varianten.
- **Feldnamen:** `02:71` `fields={value, lat, lon}` vs. `02:129-131` und `04:27-28` `latitude`/`longitude`.
- **Geo-Quelle:** `02:117` `getGeoCoordinates(parts[1],parts[2])` vs. `07:157-158` Registry-Lookup über `device_id` vs. `04:154` „einmalig bei Onboarding".
- **Backup-Verfahren:** `06:380` `influx backup` (in `09:385` selbst als veraltet markiert) vs. `09:14` `influxdb3`-CLI vs. `influxdb/README.md:130-148` tar des Datenverzeichnisses vs. `BACKUP.md:152-169` rsync.
- **Open Data vs. Datenschutz:** `01:22` „Alle Daten sind öffentlich" und `06:34` „keine personenbezogenen Daten" vs. `05:49` Ansprechperson (Name/E-Mail/Telefon), `05:61` Einverständnis-Checkbox und `07:514` Opt-Out für Standorte.
- **Secrets-Richtlinie:** `AGENTS.md:40` „Secrets live only in `.env` / `.env.smtp.password`" vs. `docs/TASMOTA_SETUP.md:24,60`, `mosquitto/README.md:74-75,88` und `zz_xx.txt` (Klartext-Passwörter).
- **CI-Status im Audit veraltet:** `blue-team-audit/interim/12_ast_linting.md:12-20` „kein Ruff/Mypy im CI" vs. `ci.yml:23-29` (beides läuft).
- **Branch-Protection-Checknames:** `.github/BRANCH_PROTECTION.md:37` `CI / lint & type-check` vs. tatsächlicher Job-Name `Python lint & type-check` (`ci.yml:11`).
- **Dokument-Brüche:** `mosquitto/README.md:44,119-122` Self-Links/fehlendes Kapitel; `05:258-270` defektes Markdown; `grafana/provisioning/alerting/README.md:64` referenziert nicht vorhandene Datei.

### 2.7 Weitere Beobachtungen

- **D17 (kritisch, Secrets):** Die **versionierte** Datei `zz_xx.txt` enthält im Klartext `Password1 Hallenbad23` (WLAN) und `MqttPassword uwbox23pw` / `MqttUser de-hh-mintfv-uwbox23`. Die unversionierte Duplikat-Datei `mintfv.peddy.net:` im Repo-Root hat denselben Inhalt (Copy/Paste-Artefakt). Das Blue-Team-Audit behauptet in `11_secrets_hygiene.md:47-52` bzw. F101 „keine Hardcoded Secrets" – das ist damit widerlegt. **Empfehlung:** Datei entfernen, Passwörter am Gerät und im Broker rotieren (Entfernen aus Git reicht nicht, sie bleiben in der Historie), danach `git-secrets`/`gitleaks` im CI ergänzen. Löschung/Rotation nur nach Bestätigung, da produktive Zugangsdaten betroffen sind. **Entscheidung 2026-11-19: keine Änderung** – Finding bleibt als akzeptiertes Risiko dokumentiert.
- **Totcode/unbenutzt:** `_generate_password()` (`mqtt/routes.py:54-57`), `list_mqtt_users()` (`mqtt/service.py:162-166`), `passlib`-Dependency (nie importiert).
- **Tests:** 9 Unit-Tests, ausschließlich Health/Mail/Migration. Keine Tests für Routes, Auth-Flows, MQTT-Service oder ACL-Logik. CI testet nur Ruff/Mypy + Playwright-Smoke (kein pytest).
- **Auth-Kleinigkeit:** `next`-Redirect-Schutz prüft nur `startswith("/")`; `//host/...` würde durchgehen (`auth/routes.py:151`).

---

## 3. Produktive Laufzeit (mintfv.peddy.net)

**Container (alle up, 12 Stück):**

| Service | Image | Status |
|---|---|---|
| nginx | `nginx:1.29.4-alpine` | healthy, 80/443/8883 |
| mosquitto | `eclipse-mosquitto:2.0.22` | healthy |
| mosquitto-reload | lokal gebaut | up |
| mosquitto-admin | `eclipse-mosquitto:2.0.22` | up |
| selfservice | lokal gebaut | healthy (13 h) |
| influxdb | `influxdb:3.8.0-core` | healthy, 8181 |
| grafana | `grafana/grafana:12.3.1` | healthy |
| nodered | `nodered/node-red:4.1.2` | healthy |
| certbot | `certbot/certbot:v5.2.2` | healthy |
| smtp-relay | `ghcr.io/devture/exim-relay:4.99.1-r0-2` | healthy |
| mcp-grafana | `grafana/mcp-grafana:0.14.0` | up |
| decap-cms | `itsmejoeeey/docker-decap-cms-standalone:3.0.9` | healthy |

**Git/Deploy:** Zum Zeitpunkt der Analyse lagen Produktion und Repo auf `e1b95a3`, Produktion zusätzlich mit einer uncommitteten CSS-Änderung (236+/26−), die exakt im laufenden Container aktiv war (md5 host == container). Der Stand wurde per SCP übernommen, per md5 verifiziert und als `16a4b9b` (`style: improve selfservice accessibility and responsiveness`) committet. **Produktion läuft jetzt einen Commit hinter dem Repo** – beim nächsten Deploy wird der CSS-Stand identisch, sofern das Image neu gebaut wird.

**Datenbank:** `users=2` (beide `role=user`, verifiziert, `tenant_id=NULL`), `tenants=0`, `mqtt_accounts=0`, `devices=0`, Alembic-Revision `001_initial`.

**mosquitto.acl:** manuell gepflegt. Mischt zwei Schemas:
- Alt: `tenant/{tenant-a,b,c}/…` mit `commands/{device}/#`
- Neu: `umweltbox/de-nrw-rs-koeln/…`, `umweltbox/de-be-ag-klima/…`
- Zusätzlich `user healthcheck`, `user master-admin` (readwrite `#`)

**nginx:** Locations `/grafana/`, `/nodered/`, `/influxdb/`, `/selfservice/`, `/cms/`, `/auth`, `/callback`, `/assets/`. Keine `/onboarding`-, `/downloads`- oder Public-API-Route. `selfservice_general` = 5 r/s (deckt sich mit README).

**Fazit Laufzeit:** Der Selfservice wird aktuell effektiv nur als Login-/Registrierungsfront genutzt. Die gesamte Tenant-/MQTT-Geschäftslogik ist „verbaut, aber nicht in Betrieb“.

---

## 4. Was bereits übereinstimmt (keine Korrektur nötig)

- Service-Liste und interne Ports in `README.md` ↔ `docker-compose.yaml` ↔ `docker ps`.
- InfluxDB 3 Core, Port 8181, kein Web-UI, Admin-Token-Datei (auch `AGENTS.md`, `09`).
- UIDs/GID 2100, `read_only`+`tmpfs`, `cap_drop: ALL`, `no-new-privileges`.
- Germanische Selfservice-Routen (`/registrieren`, `/anmelden`, `/passwort-vergessen`, `/verifizierung-erneut-senden`, `/passwort-aendern`).
- MQTT-Passworthash-Format `$7$101$<salt>$<hash>`; `fcntl.flock()`-Schutz; reload.trigger + SIGHUP-Sidecar.
- Token-Gültigkeiten 24 h / 1 h; E-Mail over internen `smtp-relay:8025`.
-entrypoint: `db stamp head` (nur bei DB ohne alembic_version) + `db upgrade`, dann gunicorn.

---

## 5. Fachlichkeiten Selfservice – Zielbild vs. Ist

Aus den Dokumenten (02/03/05/09) lässt sich folgendes gewünschtes Fachmodell ableiten. Stand 2026-11-19: **F1–F3 und F8 sind umgesetzt** (Entscheidung: Admin-Freigabe statt Auto-Approval).

| Nr. | Fachlichkeit | Ziel (Doku) | Umsetzungsstand | Offen |
|---|---|---|---|---|
| F1 | Tenant anlegen, Tenant-ID nach `03` | zentraler Onboarding-Schritt | **umgesetzt**: `/selfservice/tenant/beantragen`, ID `de-{bl}-{schultyp}-{name}` inkl. Kollisionssuffix, Status `pending` | Bearbeitung der Stammdaten; Groß-/Kleinschreibung der ID |
| F2 | Device-Registry (Tasmota/RPi/Telegraf) | Geräte-Registrierung mit Standort | **umgesetzt**: CRUD unter `/selfservice/tenant/.../geraete/...`, Verknüpfung mit MQTT-Account | Standort pro Gerät (lat/lon) noch am Tenant |
| F3 | MQTT-Accounts rollen-/gerätegerecht | admin / sensor / nodered / privat | **umgesetzt**: Rollen admin/sensor/nodered, `device_id` aus F2, Fail-Closed bei unbekannter Rolle/fehlendem Gerät, Topic-Anzeige korrigiert | Privatpersonen-Sondermodell (`03:52-55`) noch nicht |
| F4 | Verbindungsdaten / Tasmota-Konfig | Config-Download pro Gerätetyp | **umgesetzt (Tasmota):** `tasmota_config.txt` + QR aus dem einmaligen POST; FullTopic `umweltbox/%topic%/%prefix%/`; Sensor-ACL an Spec angepasst | RPi-/Telegraf-Configs, Live-Abnahme mit Test-Tenant |
| F5 | Multi-Step-Onboarding-Wizard | 4 Schritte laut `09:408-429` | nur Einzelformen (F1/F2/F3) | Wizard, Auto-Approval-Option |
| F6 | InfluxDB-/Grafana-Zugang provisioning | Tokens/Buckets/Dashboards pro Tenant | fehlt; Doku teils auf v2/Flux-Stand | **auf InfluxDB 3 Core umschreiben** (keine Buckets-API wie v2) |
| F7 | Live-Verifikation erster Datenpunkt | Portal zeigt MQTT/Influx/Grafana-Status | fehlt | optional, nach Datenmodell geklärt |
| F8 | Admin-Rolle & Freigabe-Workflow | Admin-Interface | **umgesetzt**: `admin_required`, Freigabe/Suspendierung, Admin-Navigation | Rollenverwaltung (User→Admin) nur via DB |
| F9 | Doku & UX auf Stand | – | **umgesetzt**: Doku-Korrekturen, Statusbanner, CSS-Commit `16a4b9b`, 16 neue Tests | – |

**Reihenfolge war:** F9 → F1+F2+F3+F8 (abgeschlossen) → offen: F4/F5 → F6/F7.

---

## 6. Nächste Schritte

1. **Deploy:** Produktion liegt einen Commit zurück (`e1b95a3` → `16a4b9b` + Feature-Commit). Nach dem Deploy erneut abgleichen.
2. **Akzeptiertes Risiko:** `zz_xx.txt` / `mintfv.peddy.net:` bleiben unverändert (Entscheidung 2026-11-19); Finding D17 bleibt dokumentiert.
3. **Doku-Rest:** ACL-Details in `03` (`cmnd` vs. `commands`, `$SYS`) und InfluxDB-v2-Beispiele in `05` sind weiterhin nur teilweise korrigiert.
4. **Nächste Fachlichkeiten (Bedarf klären):** F4 Tasmota-Config-Download umgesetzt; offen bleiben F5 Wizard, F6 InfluxDB-3-Zugang, F7 Live-Verifikation, Privatpersonen-Modell aus `03:52-55`.

---

## 7. Nachtrag 2026-11-26: `mqtt-acl-haertung`

Der OpenSpec-Change `mqtt-acl-haertung` ist umgesetzt und archiviert (`openspec/changes/archive/2026-11-26-mqtt-acl-haertung/`); die Anforderungen stehen nun dauerhaft in `openspec/specs/mqtt-access-control/spec.md`. Gegenüber Abschnitt 2 und 3 ergeben sich folgende Live-Fakten:

| Punkt | vorher | jetzt |
|---|---|---|
| `de-hh-mintfv-uwbox02` | `topic write #` und `topic read #` | gescopt wie uwbox23: `write umweltbox/de-hh-mintfv-uwbox02/#`, `read .../cmnd/#`, `read $SYS/broker/version` |
| `mcp-admin-user` | `readwrite #`, in ACL und Passwortdatei | entfernt (kein bekannter Verwender, keine Verbindungen in 30 Tagen Logs) |
| `nodered-writer` | `readwrite #` | `read umweltbox/#` (der Flow hat keine `mqtt out`-Knoten) |
| `mosquitto.acl` | Modus `666` | Modus `660`, Besitz `2003:2100` (Selfservice und Host-Skript in GID 2100 schreiben weiter) |
| Testidentität | – | `mintfv-smoketest` mit vier gescopten Regeln; Credentials nur in `.env` auf `mintfv` |
| Smoketest | nur self-contained Playwright-Seite | `tests/mqtt-acl-smoke.sh`: statische ACL-Prüfung, MQTT-Round-Trip in `smoketest/…`, InfluxDB-Canary auf uwbox23 |

Verifiziert: Abschluss-Smoke `SMOKE_OK`, uwbox23-Daten unverändert und aktuell, einzige verbleibende ungescopte Regel ist `master-admin`. Backups liegen unter `mosquitto/config/backups/*-20261126-191357` (Modus 640).

Weiterhin offen: D25 – die Topic-Schemata `tenant/…` gegenüber `umweltbox/…` sowie `cmnd` gegenüber `commands` sind **nicht** vereinheitlicht. Ebenso offen bleiben F5–F7 und das Privatpersonen-Modell aus `03:52-55`. Produktion läuft unverändert auf `e1b95a3`; der lokale Branch `openspec` ist 6 Commits voraus.

---

## 8. Nachtrag 2026-11-26: F6 – InfluxDB-3-Doku

Der OpenSpec-Change `influxdb3-doc-alignment` gleicht die Dokumentation an den produktiven Stand an; es findet **keine Laufzeitänderung** statt. Live-Befunde:

| Punkt | Doku vorher | Ist |
|---|---|---|
| Query-Sprache | Flux / v2-API | SQL/InfluxQL über HTTP-API oder `influxdb3`-CLI; InfluxDB 3 Core unterstützt kein Flux |
| DB-Name | `mydb`, `umweltbox*` | produktiv `mintfv`; `umweltbox` existiert als separate Alt-DB mit gleichnamiger Tabelle |
| Measurement | `umweltbox` (Zielbild) | `sensors` in `mintfv`, Tags `tenant_id`/`device_id`/`category`/`sensor_type`, Field `value` |
| Downsampling/Retention | vier Buckets, Flux-Tasks | keine Plugins, keine Trigger, keine Aggregate; keine Retention konfiguriert |
| Tokens | Tokens/Buckets pro Tenant | `influxdb3 create token` kennt nur `--admin`; kein Tenant-Provisioning |
| Backup | `influx backup`, tar/rsync/CLI widersprüchlich | Dateisystem-Snapshot von `influxdb/data/`; `influxdb3` hat kein `backup`-Subkommando, `query`/`write` nur für logische Exporte |
| Grafana | `mintfv-dashboard.json` mit Flux | Dashboard scheiterte am leeren Titel und wurde nie geladen; der Change `flux-beispiele-bereinigen` repariert die Struktur und stellt alle Queries auf SQL um |

Die Meta-Dokus `04`, `05`, `06`, `09`, `influxdb/README.md`, `grafana/README.md`, `README.md` und `BACKUP.md` wurden entsprechend markiert bzw. korrigiert; ein ausführbares SQL-Beispiel steht in `04_InfluxDB_Schema.md`. Weiterhin Zielbild und nicht umgesetzt bleiben F5 Wizard, F6 Retention/Downsampling und Token-Provisioning, F7 Live-Verifikation sowie das Privatpersonen-Modell; F4 ist für Tasmota umgesetzt.

---

## 9. Nachtrag 2026-11-26: Flux-Beispiele bereinigt

Der OpenSpec-Change `flux-beispiele-bereinigen` hat alle ausführbaren Flux-Beispiele entfernt oder in SQL umgeschrieben:

- **Gelöscht:** die Flux-Task-/Downsampling-Beispiele in `04` und `06` (inkl. `_tasks`-Monitoring), Prompt 3.1 und Template 2 in `09`.
- **Auf SQL umgestellt:** die Abfragebeispiele in `04`, alle fünf Kartenbeispiele in `07` (mit neuem Statusbanner), die Prompt-Texte in `09`, der Architekturgraph in `02` und die Vergleichstabelle in `08`.
- **Grafana:** `mintfv-dashboard.json` hatte Titel/UID unter `dashboard` verschachtelt und wurde deshalb nie provisioniert („Dashboard title cannot be empty"). Die Datei wurde auf Top-Level-Struktur korrigiert und ihre fünf Queries auf `rawSql` umgestellt. Die Tenant-Variable nutzt jetzt `$__timeFilter(time)` statt eines 90-Tage-Fensters (Parquet-Dateigrenze in 3 Core).

Live verifiziert: Dashboard in der Grafana-API mit `uid=mintfv-umweltbox-uebersicht` sichtbar (HTTP 200), vier SQL-Targets und die Tenant-Variable vorhanden, keine Provisionierungsfehler; die Panel-Abfrage liefert aktuelle Werte aus `sensors`.

Offen bleibt weiterhin echtes Downsampling/Retention (keine Plugins, keine Trigger) – es ist Zielbild und nicht implementiert.

---

## 10. Nachtrag 2026-11-26: F4 – Tasmota-Config-Download

Der OpenSpec-Change `f4-tasmota-config-download` (archiviert unter `openspec/changes/archive/2026-11-26-f4-tasmota-config-download/`, Anforderungen dauerhaft in `openspec/specs/device-config-download/spec.md`) ergänzt den Config-Download für Tasmota. Er bleibt bewusst auf diesen Gerätetyp beschränkt; `rpi` und `telegraf` sind nicht enthalten.

| Punkt | vorher | jetzt |
|---|---|---|
| Config-Datei | nicht vorhanden | `tasmota_config.txt` mit einer `Backlog0`-Zeile, erzeugt im selben authentifizierten POST wie die Once-Credentials |
| Passwort | nur in der Once-Seite | zusätzlich in Datei/QR, aber nicht gespeichert, nicht geloggt und nicht per GET erneut abrufbar |
| QR-Code | nicht vorhanden | clientseitig aus derselben Zeile erzeugt, keine neue Python-Abhängigkeit |
| FullTopic | `05` widersprüchlich (`%prefix%/%topic%/`), Live `umweltbox/%topic%/%prefix%/` | verbindlich `umweltbox/%topic%/%prefix%/` mit `Topic {tenant}/{device}`; `05` korrigiert |
| Sensor-ACL (Code) | `read umweltbox/{tenant}/cmnd/{device}/#` | `read umweltbox/{tenant}/{device}/cmnd/#`, wie von `mqtt-access-control` bereits gefordert |
| Geräteverknüpfung | `Device.mqtt_account_id` blieb bei der Account-Anlage leer | wird gesetzt; doppelte Verknüpfungen werden abgelehnt |

Verifiziert: 44 Unit-Tests in `selfservice/tests`, `ruff`/`mypy` und die Playwright-Suite `selfservice` (7/7) gegen einen lokalen Docker-Stack, inklusive Dateiname, Dateiinhalt und QR-Quelle des Downloads. Der Produktiv-Deploy erfolgte am 2026-11-26 auf `f6c23b8`: Selfservice-Image neu gebaut, nginx per SIGHUP reloaded, `/selfservice/health`, `/selfservice/anmelden` und das statische QR-Asset liefern 200, `./tests/mqtt-acl-smoke.sh` → `SMOKE_OK`. Die manuell gepflegten ACL-/Passwd-Dateien sind per md5 unverändert (Modus 660), die DB hat weiterhin 0 Tenants/Devices/Accounts. Die Abnahme an einem echten Test-Tenant steht aus.

---

## 11. Nachtrag 2026-11-26: InfluxDB nach Container-Neustart nicht gestartet

Nach `./mintfv.sh stop` (`docker compose down`) und anschließendem Start blieb `mintfv-influxdb-1` in einer Restart-Schleife; Grafana, Node-RED, Selfservice, nginx und weitere Dienste blieben im Status `Created`.

**Ursache:** `docker-compose.yaml` setzte für InfluxDB `ulimits.nofile` auf `soft 512 / hard 1024`. InfluxDB 3 Core baut beim Start den Table-Index-Cache aus allen Snapshots auf; unter `influxdb/data/mintfv-node-0/snapshots/` lagen inzwischen **578** `*.info.json`-Dateien. Der Start brach beim Initialisieren des Write Buffers mit `Too many open files (os error 24)` ab. Es war kein Daten- oder Tokenproblem – der Host erlaubt `ulimit -Hn 524288`.

| Punkt | vorher | jetzt |
|---|---|---|
| `nofile` (InfluxDB) | soft 512 / hard 1024 | soft 4096 / hard 8192 (Commit `8c47b6f`) |
| InfluxDB | Restart-Schleife | healthy, interner `/health` = `OK` |
| Abhängige Dienste | `Created` | alle Up/healthy nach `docker compose up -d` |

Behoben durch Neuerstellen des Containers mit den neuen Limits, anschließend `docker compose up -d` und nginx-SIGHUP. Verifiziert: Selfservice via nginx `200`, Grafana `302` (Login-Redirect), `./tests/mqtt-acl-smoke.sh` → `SMOKE_OK` mit 15 InfluxDB-Punkten/30 min. Die Snapshot-Zahl wächst weiter; das neue Limit schafft deutlichen Puffer, die Snapshot-/Retention-Entwicklung bleibt aber zu beobachten.

Der Neustart selbst war ordnungsgemäß: `./mintfv.sh stop` entspricht `docker compose down`, `./mintfv.sh start` entspricht `docker compose up -d`. Er war lediglich der Auslöser, weil danach das alte `nofile`-Limit auf die inzwischen 578 Snapshot-Dateien traf.

---

*Erstellt: 2026-11-19. Nachfolgende Änderungen an Doku/Code bitte hier gegenlesen.*
