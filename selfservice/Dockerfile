# ── Stage 1: Lint & Test ─────────────────────────────────────────────
FROM python:3.12.13-slim AS lint

WORKDIR /app

COPY requirements.txt requirements-dev.txt pyproject.toml ./
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY app/ app/

# Bricht den Build ab, wenn Checks fehlschlagen
RUN ruff check app/ && \
    ruff format --check app/ && \
    mypy app/ && \
    flake8 app/ && \
    pylint app/ && \
    bandit -r app/ -ll -q

# ── Stage 2: Runtime ─────────────────────────────────────────────────
FROM python:3.12.13-slim AS runtime

# Sicherheit: Keine Root-Rechte im Container
RUN groupadd -g 2100 ssl-certs && \
    useradd -u 2007 -g 2100 -m -s /bin/bash selfservice

# curl für Healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Verzeichnisse für Daten und Reload-Signal
RUN mkdir -p /app/data /app/reload && \
    chown -R 2007:2100 /app/data /app/reload && \
    chmod 770 /app/reload

USER 2007:2100

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD curl -fsS4 --max-time 5 http://localhost:5000/selfservice/health || exit 1

ENTRYPOINT ["./entrypoint.sh"]
