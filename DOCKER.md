# Docker Configuration Hints for MintFV Project

**Last Updated: December 26, 2025**

## ⚠️ Critical Security Rules

### NEVER Do This:
- ❌ `chmod 777` or `chmod -R 777` - Major security risk!
- ❌ `chown` with world-writable permissions
- ❌ Run containers as root
- ❌ Use `--privileged` flag unless absolutely necessary

### DO This Instead:
- ✅ Use `docker compose exec` to run commands in containers
- ✅ Set explicit user:group (e.g., `2001:2100`)
- ✅ Use mode 750 for directories, 640 for files
- ✅ Ask user for one-time host cleanup if absolutely necessary

## User ID & Group ID Convention

**Critical Rule: All Docker containers use User IDs starting from 2001 and shared Group ID 2100**

### UID/GID Mapping

- **GID 2100** (`ssl-certs`) - Shared group for all services (allows file sharing)
- **UID 2001** (`nginx`) - Nginx webserver
- **UID 2002** (`certbot`) - Let's Encrypt certificate management
- **UID 2003** (`mosquitto`) - MQTT broker (future)
- **UID 2004** (`nodered`) - Node-RED data processing (future)
- **UID 2005** (`influxdb`) - Time series database (future)
- **UID 2006** (`grafana`) - Visualization dashboard (future)

### Why Shared GID 2100?

The shared group allows multiple containers to access the same files securely:
- **nginx** (UID 2001) reads SSL certificates created by **certbot** (UID 2002)
- Both use GID 2100, allowing read access without 777 permissions
- Files are owned by specific UIDs but group-readable by all services

### Docker Compose Example

```yaml
services:
  nginx:
    user: "2001:2100"      # UID:GID
    group_add:
      - "2100"             # Add to ssl-certs group
  
  certbot:
    user: "2002:2100"
    group_add:
      - "2100"
```

### File Permissions

**Recommended permissions:**
- Certificates: `750` (owner rwx, group r-x, others ---) for directories
- Certificate files: `640` for private keys, `644` for public certs
- Configs: `644` (owner rw, group r, others r)
- Writable data: `770` (owner+group rwx, others ---)

**Never use 777!** Always use specific user/group permissions.

**Note:** Docker volumes mounted from host maintain host permissions. Use `sudo` for one-time permission fixes if needed, or use init containers to set correct ownership.

## Logging Strategy

**All logs go to STDOUT/STDERR** - No log files in containers!

```yaml
# Automatic log rotation via Docker
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
    compress: "true"
```

**Benefits:**
- Kubernetes-ready
- Centralized log management
- Automatic rotation
- No disk space issues in containers

**View logs:**
```bash
./mintfv.sh logs nginx    # Specific service
docker compose logs -f    # All services, follow mode
```

## Security Features to Always Implement

### 1. Read-Only Root Filesystem

```yaml
services:
  nginx:
    read_only: true
    tmpfs:
      - /var/cache/nginx:uid=2001,gid=2100,mode=0750
      - /var/run:uid=2001,gid=2100,mode=0750
      - /tmp:uid=2001,gid=2100,mode=1777
```

### 2. Capability Dropping

```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
  - NET_BIND_SERVICE  # Only for nginx/services binding to ports <1024
```

### 3. Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 128M
      pids: 100
    reservations:
      cpus: '0.25'
      memory: 64M
```

### 4. Health Checks

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "--max-time", "5", "http://localhost:8080/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 5. Automatic Log Rotation

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
    compress: "true"
```

### 6. Isolated Bridge Network

```yaml
networks:
  mintfv-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 7. Dependency Management

```yaml
depends_on:
  certbot-init:
    condition: service_healthy
  nginx:
    condition: service_healthy
```

## Init Container Pattern

Use init containers for one-time setup tasks:

```yaml
certbot-init:
  image: certbot/certbot:latest
  command: >
    sh -c '
    if [ ! -f "/etc/letsencrypt/.initialized" ]; then
      # Perform initialization
      touch /etc/letsencrypt/.initialized
    fi
    '
  healthcheck:
    test: ["CMD", "test", "-f", "/etc/letsencrypt/.initialized"]
    interval: 5s
    retries: 1
```

## Volume Mounts Best Practices

```yaml
volumes:
  # Read-only mounts for configs
  - ./nginx/conf:/etc/nginx/conf.d:ro
  
  # Read-write for data that needs to be modified
  - ./certbot/conf:/etc/letsencrypt:rw
  
  # Shared read-only for SSL certificates
  - ./certbot/conf:/etc/letsencrypt:ro
```

## Shared Configuration Templates

Use YAML anchors to avoid repetition:

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
    compress: "true"

x-security: &default-security
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL

services:
  nginx:
    <<: *default-security
    logging: *default-logging
```

## Environment Variables

Load from config.yaml via environment variables:

```yaml
environment:
  - DOMAIN=${DOMAIN:-mintfv.peddy.net}
  - EMAIL=${EMAIL:-admin@example.com}
  - TZ=${TZ:-Europe/Berlin}
```

## Service Restart Policies

```yaml
restart: unless-stopped  # For long-running services
restart: "no"           # For init containers (run once)
```

## Future Services

When adding new services:
1. Assign next sequential UID (2003, 2004, etc.)
2. Use shared GID 2100
3. Apply all security features
4. Add health checks
5. Configure logging
6. Set resource limits
7. Document in this file

## Checklist for New Services

- [ ] UID starting from 2001+
- [ ] GID 2100 with group_add
- [ ] Read-only root filesystem (if possible)
- [ ] Capability dropping
- [ ] Resource limits
- [ ] Health check
- [ ] Log rotation
- [ ] Dependency management (depends_on)
- [ ] Security headers (for web services)
- [ ] Network isolation

## References

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
