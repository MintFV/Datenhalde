# CI notes

This repository includes a minimal CI and Dependabot setup.

- `CI` (`.github/workflows/ci.yml`): runs Python lint/type checks and a Playwright smoke test on PRs to `refactorPED` using GitHub-hosted runners (`ubuntu-latest`).
- `Dependabot` (`.github/dependabot.yml`): watches `pip` in `/selfservice` and `npm` in `/tests` weekly.

Required repository secrets for full integration (add via GitHub Settings → Secrets):

- `INFLUXDB_TOKEN` — Admin token for InfluxDB (if running integration tests that need access).
- `SELFSERVICE_SECRET_KEY` — Secret key for the `selfservice` Flask app.
- `SMTP_USER_PROVIDER` — SMTP user for the relay (in `.env`, copied from `env.example`).
- `SMTP_PASSWORD` — SMTP password in the separate `.env.smtp.password` file, written as `SMTP_PASSWORD='…'` (see `README.md`).

E2E workflow (`.github/workflows/e2e.yml`) is manual (`workflow_dispatch`) and will run `docker compose up -d --build` and the Playwright runner. It is intended for manual runs or scheduled runs and may require longer time and resources.

`MQTT ACL smoke` (`.github/workflows/mqtt-smoke.yml`) runs on **every push, on any branch**. It starts an isolated stack of mosquitto and InfluxDB on the runner using `.github/mqtt-smoke-compose.yml`, throwaway ACL/password files and a generated admin token, seeds one synthetic `sensors` point for `de-hh-mintfv-uwbox23`, and runs `tests/mqtt-acl-smoke.sh`. It checks that the smoke-test tooling still works after a push. There is no SSH or other production access from GitHub Actions.

The results are published via MQTT to `mintfv.peddy.net:8883` and written to the production InfluxDB by Node-RED. This uses exactly two repository secrets, `MQTT_SMOKE_USER` and `MQTT_SMOKE_PASS`, containing the scoped identity `mintfv-smoketest` (write only under `smoketest/mintfv-smoketest/#`). No admin token is stored in GitHub. The points carry `source=ci` plus `run_id`, `sha` and `ref` and are visible in the `mintfv-smoketest` Grafana dashboard; manual runs on `mintfv` use `source=prod`. See `docs/Projekt-Meta-Doku/11_Smoketest_Datenfluss.md` for the flow.
