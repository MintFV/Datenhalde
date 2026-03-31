# Copilot Instructions for MintFV Project

## Current Session Info

### Date
**Current date: December 27, 2025**

*Important: Always ask for the current date at the start of each session and update this section. Use this date for any date-dependent operations or documentation.*

## Critical Rules

### Security & Permissions
- **NEVER use `chmod 777` or `chmod -R 777`** - This is a security risk
- **NEVER use `chown` with world-writable permissions**
- Instead: Use `docker compose exec` to run commands inside containers with correct user context
- If permissions need fixing, ASK the user to do one-time cleanup on host level

### File Permissions Strategy
- Use specific user:group (e.g., `2001:2100`)
- Use mode 750 for directories (rwxr-x---)
- Use mode 640 for files (rw-r-----)
- All containers share GID 2100 (ssl-certs group) for shared file access

### Docker Best Practices
- Always use `docker compose` (not `docker-compose`)
- User IDs start at 2001, shared GID 2100 (see README.md Security section)
- Always implement healthchecks and depends_on where possible
- Use tmpfs for writable directories in read-only containers
- **Healthchecks**: Always use `curl -fsS` (never `wget`)
  - `-f`: Fail silently on HTTP errors
  - `-sS`: Silent mode but show errors
  - `--max-time X`: Timeout in seconds
  - Example: `["CMD", "curl", "-fsS", "--max-time", "5", "http://localhost:8080/"]`

### Git Best Practices
- **ALWAYS use `git mv` instead of `mv`** - This preserves file history in Git
- **Commit messages**: One-liner that abstractly describes what happened, no detailed explanations
  - ✅ Good: "docs: Integrate DOCKER.md into README.md"
  - ❌ Bad: "docs: Integrate DOCKER.md into README.md and remove file\n\n- Add Docker Security Best Practices section..."
- This is critical for tracking documentation and code evolution

## Current Project State

### Last Updated
Project state as of: **March 31, 2026**

### Active Domain
- Domain: mintfv.peddy.net
- Email: user@example.com
- Currently using: **Production mode with real Let's Encrypt certificates**
- HTTPS: ✅ Active and working

### Service Status
- nginx: ✅ Running (HTTP + HTTPS, Port 80/443)
- certbot: ✅ Running (auto-renewal every 12h)
- grafana: ✅ Running (accessible at /grafana/)
- influxdb: ✅ Running (InfluxDB 3.8 Core, accessible at /influxdb/)
  - **Version**: InfluxDB 3 Core (3.8.0)
  - **Port**: 8181 (changed from 8086)
  - **Authentication**: Admin token in `./influxdb/tokens/admin.token` (JSON format)
  - **No Web-UI**: InfluxDB 3 Core has no built-in UI (use Grafana or CLI)
  - **APIs**: v1 (InfluxQL), v2 (Compatibility), v3 (Native)
- nodered: ✅ Running (accessible at /nodered/)
  - **Version**: Latest (nodered/node-red)
  - **Port**: 1880 (internal)
  - **Authentication**: Configured via settings.js (adminAuth)
  - **Multi-Tenancy**: ❌ NOT supported - single workspace for all users
  - **InfluxDB Integration**: Via node-red-contrib-influxdb
- mosquitto: ⏳ Planned (not yet implemented)

### Selfservice-Portal & Mosquitto-Reload
- selfservice: ✅ Running (Flask, accessible at /selfservice/)
  - **Framework**: Flask 3.1 + SQLAlchemy + gunicorn
  - **Port**: 5000 (internal)
  - **Features**: Benutzer-Registrierung, E-Mail-Verifikation, MQTT-Account-Verwaltung
  - **Datenbank**: SQLite in `./selfservice/data/selfservice.db`
- mosquitto-reload: ✅ Running (Sidecar für Mosquitto-Reload via SIGHUP)
  - **Image**: Eigenes Dockerfile (alpine + inotify-tools)
  - **Shared PID-Namespace**: `pid: "service:mosquitto"`
  - **Trigger**: Shared Volume `selfservice-reload`

### Service UIDs/GIDs
- nginx: 2001:2100
- certbot: 2002:2100
- mosquitto: 2003:2100 (planned)
- nodered: 2004:2100 ✅
- influxdb: 2005:2100 ✅
- grafana: 2006:2100 ✅
- selfservice: 2007:2100 ✅
- mosquitto-reload: 2003:2100 ✅ (shared with mosquitto)
- Shared GID: 2100 (ssl-certs)

## Workflow Commands

### Container Operations
```bash
# Execute command in container with correct user
docker compose exec -u 2001:2100 nginx sh -c "command"

# Fix permissions inside container (if needed)
docker compose exec certbot-init chown -R 2002:2100 /etc/letsencrypt

# One-time init container
docker compose run --rm certbot-init
```

### Preferred Cleanup Pattern
```bash
# Ask user first, then they run:
docker compose down -v
rm -rf ./certbot/conf/* ./certbot/logs/* ./nginx/logs/*
```

## Documentation Structure
- certbot/SSL-SETUP.md - SSL/HTTPS setup process
- BACKUP.md - Backup strategy and locations
- config.yaml - Main configuration (see config-example.yaml)
- selfservice/README.md - Selfservice-Portal Dokumentation
- nginx/README.md - Reverse Proxy & Rate Limiting
- mosquitto/README.md - MQTT Broker & ACL
- grafana/README.md - Grafana Dashboards
- influxdb/README.md - InfluxDB 3 Core
- nodered/README.md - Node-RED Flows

## Common Pitfalls
1. Don't create scripts on host - use container entrypoints/commands
2. Don't assume default permissions work - always set explicit user:group
3. Don't use --privileged unless absolutely necessary
