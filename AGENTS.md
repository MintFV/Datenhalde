# AGENTS.md

## What this repo is

Self-hosted IoT platform ("MintFV") defined almost entirely by `docker-compose.yaml` plus per-service config directories (`nginx/`, `mosquitto/`, `grafana/`, `influxdb/`, `nodered/`, `certbot/`, `smtp-relay/`). The only traditional application is `selfservice/` — a Flask 3.1 portal (SQLAlchemy + gunicorn) for user registration and MQTT account management. Additional services are `mcp-grafana` (Grafana MCP server) and `decap-cms` (Git-backed CMS with GitHub OAuth). `docker-compose.yaml` remains the source of truth for service state. Documentation is mostly German, including user-facing UI routes.

## Git & CI

- Active development branch is `refactorPED`. `ci.yml` runs on push/PR to it only, with two jobs: `lint` (ruff + mypy, Python 3.11) and `node-smoke` (Playwright smoke against the minimal nginx-only `docker-compose.ci.yml`, with a fallback isolated smoke test).
- `check-no-pyc.yml` runs on **all** pushes and PRs and fails on tracked `__pycache__/`, `*.pyc`, `.pytest_cache/`. Never commit those.
- Branch protection is a recommendation, not enforced: `.github/BRANCH_PROTECTION.md`. Commit messages: single line, abstract summary, no body (team convention).
- Use `git mv`, not `mv`.
- Dependabot runs weekly for `pip` (`/selfservice`) and `npm` (`/tests`). Secrets needed for full integration: `INFLUXDB_TOKEN`, `SELFSERVICE_SECRET_KEY`, `SMTP_USER_PROVIDER`, `SMTP_PASS_PROVIDER` (see `.github/README-CI.md`).

## Commands

Lint/typecheck (mirror CI, run from repo root):

```bash
pip install -r selfservice/requirements-dev.txt
ruff check selfservice
mypy --config-file selfservice/pyproject.toml selfservice
```

Note: CI runs Python 3.11 while `selfservice/pyproject.toml` targets py312 — don't use 3.12-only syntax blindly.

- Unit tests: run `pytest` from `selfservice/` (mostly in-memory SQLite; `test_migrate.py` uses a temporary file DB). CI does **not** run these — only lint + Playwright smoke.
- Playwright E2E: `./tests/run-tests.sh [suite]` — builds a test image and runs inside Docker attached to the compose network, so the stack must be up. Suites: `landing`, `selfservice`, `grafana`, `nodered`, `influxdb`, `mosquitto`, `nginx`; `smoke` works via the wildcard fallback (`tests/run-tests.sh:39`) and is what CI calls. Each suite gets a sensible default `PW_BASE_URL` (internal service URLs).
- Full-stack E2E is manual only: `.github/workflows/e2e.yml` (workflow_dispatch).
- Stack management: `./mintfv.sh {init|start|stop|restart|status|logs [svc]|version|test-email|request-cert|force-renewal|enable-ssl|disable-ssl|cleanup}`. Post-setup validation: `./validate.sh`.
- Local stack needs `.env` (copy from `env.example`) and `.env.smtp.password` (separate file, `SMTP_PASS_PROVIDER=`). `env.example` and the compose comment use `SMTP_PASS_PROVIDER`; `README.md` and `ci.yml` currently say `SMTP_PASSWORD` — treat that as a known inconsistency. Neither file is committed; CI creates a placeholder for the latter.

## Security & operations

- Never use `chmod 777`, `chown` with world-writable permissions, or make host files world-writable. Use specific `user:group` (e.g. `2001:2100`), mode `750` for directories and `640` for files.
- Never weaken `cap_drop: ALL`, `no-new-privileges`, `read_only`, or non-root users without explicit user approval.
- Fix permissions inside containers: `docker compose exec -u 2001:2100 nginx sh -c "…"`. One-time init container: `docker compose run --rm certbot-init` (starts as root to `chown` `/etc/letsencrypt` to `2002:2100`). Ask the user before doing one-time cleanup on the host.
- Don't create helper scripts on the host — use container entrypoints/commands. Don't use `--privileged` unless absolutely necessary.
- Full compose cleanup is destructive (`docker compose down -v` + removing `certbot/`, `nginx/` state) — confirm with the user first. Pattern after confirmation: `docker compose down -v`, then remove `./certbot/conf/*`, `./certbot/logs/*`, `./nginx/logs/*`.
- Secrets live only in `.env` / `.env.smtp.password`; never commit them or print tokens/passwords in logs, commands or commits.

## Docker conventions

- Always `docker compose` (space), never `docker-compose`.
- Security defaults come from the `x-security` anchor in `docker-compose.yaml`: `no-new-privileges`, `cap_drop: ALL`, `privileged: false`, `ipc: private`. Apply healthchecks and `depends_on` where possible; use `tmpfs` for writable paths in read-only containers.
- Prefer explicit healthchecks with `curl -fsS … --max-time …`. Existing exceptions are intentional — do not "fix" them blindly: `decap-cms` uses `wget`, mosquitto uses `pidof`, certbot uses `certbot --version`, smtp-relay uses `nc`; some services have no healthcheck.
- Shared GID `2100` (ssl-certs) on containers needing shared volumes. UID map: nginx 2001, certbot 2002, mosquitto/mosquitto-reload 2003, nodered 2004, influxdb 2005, grafana 2006, selfservice 2007. Exceptions: smtp-relay uses the image user `100:101`, decap-cms the image default, certbot-init starts as root for one-time `chown`, mcp-grafana declares no user.
- `read_only: true` + `tmpfs` is used by nginx, grafana, influxdb and selfservice — not by every service. Don't assume it when editing another container.

## Selfservice specifics

- MQTT account changes flow through `selfservice/app/mqtt/service.py` (Python port of `manage_mqtt_users.sh`): it writes `mosquitto/config/mosquitto.passwd` and `mosquitto.acl` under `fcntl.flock()`, then drops a trigger file into the `selfservice-reload` volume. The `mosquitto-reload` sidecar (shares PID namespace with mosquitto via `pid: "service:mosquitto"`) sends SIGHUP. Don't edit passwd/ACL files directly on a live system without triggering a reload.
- DB migrations: Flask-Migrate/Alembic. `entrypoint.sh` runs `flask db upgrade` automatically on every container start (and `db stamp head` once for pre-migrate databases). Create migrations with `docker compose exec selfservice flask --app 'app:create_app()' db migrate -m "..."`.
- SQLite DB lives at `selfservice/data/selfservice.db` and must be owned `2007:2100` or the app errors.
- User-facing routes are German: `/selfservice/registrieren`, `/anmelden`, `/passwort-vergessen`, etc.

## InfluxDB 3 Core

- Port 8181 (not the InfluxDB 1.x/2.x 8086), no built-in web UI — use Grafana or the CLI. Admin token: `influxdb/tokens/admin.token` (JSON, read the `.token` field), also used by `validate.sh`.

## Architecture docs

- `docs/Projekt-Meta-Doku/` — project vision, architecture, MQTT topic scheme (`umweltbox/{tenant}/{device}/…`), InfluxDB schema, storage/downsampling plan, and `09_LLM_Prompts_fuer_zukuenftige_Entwicklung.md` (still says "InfluxDB 2.x" in places — this repo runs InfluxDB 3 Core).
- Per-service details: `nginx/README.md`, `mosquitto/README.md`, `grafana/README.md`, `influxdb/README.md`, `nodered/README.md`, `selfservice/README.md`, `certbot/SSL-SETUP.md`, `BACKUP.md`.
