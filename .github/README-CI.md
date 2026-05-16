# CI notes

This repository includes a minimal CI and Dependabot setup.

- `CI` (`.github/workflows/ci.yml`): runs Python lint/type checks and a Playwright smoke test on PRs to `refactorPED` using GitHub-hosted runners (`ubuntu-latest`).
- `Dependabot` (`.github/dependabot.yml`): watches `pip` in `/selfservice` and `npm` in `/tests` weekly.

Required repository secrets for full integration (add via GitHub Settings → Secrets):

- `INFLUXDB_TOKEN` — Admin token for InfluxDB (if running integration tests that need access).
- `SELFSERVICE_SECRET_KEY` — Secret key for the `selfservice` Flask app.
- `SMTP_USER`, `SMTP_PASSWORD` — If using private SMTP relay credentials.

E2E workflow (`.github/workflows/e2e.yml`) is manual (`workflow_dispatch`) and will run `docker compose up -d --build` and the Playwright runner. It is intended for manual runs or scheduled runs and may require longer time and resources.
