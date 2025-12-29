# SSL Setup with Let's Encrypt (Container-Only Workflow)

This document describes the SSL/HTTPS setup using Let's Encrypt certificates, running entirely in Docker containers.

## Overview

SSL certificates are managed by:
- **certbot-init**: One-time initialization container (creates dummy certificates for initial setup)
- **certbot**: Long-running container for automatic certificate renewal every 12 hours
- **nginx**: Webserver serving ACME challenges and HTTPS content

All operations run in containers - no host-level scripts required.

## Quick Start

### 1. Configuration

```bash
# Configure domain and email in .env
cp env.example .env
vi .env

# Set your domain and email:
DOMAIN=your-domain.com
EMAIL=your-email@example.com
```

### 2. Start Services

```bash
# Initialize system with dummy certificates and start services
./mintfv.sh start
```

This:
- Creates dummy SSL certificates for initial setup
- Starts nginx in HTTP mode with ACME challenge support
- Starts certbot renewal service for automatic certificate management
- Requests production certificates from Let's Encrypt automatically

### 3. Verify HTTPS

```bash
# Test HTTPS access
curl -I https://your-domain.com

# Check certificate
echo | openssl s_client -showcerts -servername your-domain.com \
  -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -text
```

## Certificate Lifecycle

### Automatic Renewal

Certbot automatically renews certificates:
- Checks every 12 hours (configurable in config.yaml)
- Renews when less than 30 days remaining
- Uses webroot method (no downtime)
- Logs to `certbot/logs/`

### Manual Renewal

```bash
# Dry-run test
docker compose exec certbot certbot renew --dry-run

# Force renewal
docker compose exec certbot certbot renew --force-renewal
```

### Check Certificate Expiry

```bash
# View certificate details
docker compose exec certbot certbot certificates
```

## File Locations

```
certbot/
├── conf/
│   ├── live/
│   │   └── your-domain/
│   │       ├── fullchain.pem    # Certificate + intermediates
│   │       ├── privkey.pem      # Private key
│   │       ├── cert.pem         # Certificate only
│   │       └── chain.pem        # Intermediate certificates
│   ├── archive/                 # Historical certificates
│   └── renewal/                 # Renewal configurations
├── www/
│   └── .well-known/
│       └── acme-challenge/      # ACME challenge files
└── logs/
    └── letsencrypt.log          # Certbot logs
```

## Nginx Configuration

### HTTP-Only Mode (default.conf)

```nginx
server {
    listen 8080;
    
    # ACME challenge for certificate requests
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Regular content
    location / {
        root /usr/share/nginx/html;
    }
}
```

### HTTPS Mode (ssl.conf)

```nginx
# HTTP - Redirect to HTTPS (except ACME challenge)
server {
    listen 8080;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS
server {
    listen 8443 ssl;
    
    ssl_certificate /etc/letsencrypt/live/your-domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain/privkey.pem;
    
    # Security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        root /usr/share/nginx/html;
    }
}
```

## Troubleshooting

### Certificate Request Fails

**Error: "Connection refused"**

Check:
```bash
# 1. DNS resolves correctly
nslookup your-domain.com

# 2. nginx is running and healthy
./mintfv.sh status

# 3. Port 80 is accessible from internet
curl http://your-domain.com/.well-known/acme-challenge/test

# 4. Check nginx logs
./mintfv.sh logs nginx
```

**Error: "Unable to change owner and uid of webroot"**

This is a warning, not an error. Certbot cannot chown files but will still work.

**Error: "Rate limit exceeded"**

You've hit Let's Encrypt production limits:
- Wait 1 week before trying again
- Delete the old certificate and restart:
  ```bash
  rm -rf certbot/conf/live/your-domain/
  rm -rf certbot/conf/archive/your-domain-*/
  ./mintfv.sh restart
  ```

### Certificate Not Loading

```bash
# Check certificate exists
ls -la certbot/conf/live/your-domain/

# Check nginx config syntax
docker compose exec nginx nginx -t

# Check nginx logs
./mintfv.sh logs nginx

# Restart nginx
./mintfv.sh restart
```

### ACME Challenge Not Working

```bash
# Test ACME challenge directory
echo "test" > certbot/www/test.txt
curl http://your-domain.com/.well-known/acme-challenge/../../test.txt

# Should return "test"
# If not, check nginx configuration and logs
```

### Request New Certificate

If you need to request a new certificate:
```bash
# Remove old certificate
rm -rf certbot/conf/live/your-domain/
rm -rf certbot/conf/archive/your-domain-*/

# Restart services - certbot will automatically request new certificate
./mintfv.sh restart
```

## Security Considerations

### File Permissions

Certificates are protected by GID 2100:
- nginx (UID 2001) reads certificates
- certbot (UID 2002) writes certificates
- Both share GID 2100 for access
- Permissions: 750 (owner+group only)

### Private Key Security

- Private keys stored in `certbot/conf/live/your-domain/privkey.pem`
- Never commit to git (.gitignore should exclude certbot/conf/)
- Backup securely (see [BACKUP.md](BACKUP.md))
- Permissions: 640 (owner rw, group r)

### Container Security

- certbot runs with minimal capabilities
- Read-only filesystem where possible
- No new privileges allowed
- Resource limits enforced

## Advanced Topics

### Custom Certificate Path

Edit `nginx/conf/ssl.conf`:
```nginx
ssl_certificate /path/to/custom/cert.pem;
ssl_certificate_key /path/to/custom/key.pem;
```

### Multiple Domains

Currently supports single domain. For multiple domains:
1. Edit config.yaml (future feature)
2. Request multi-domain certificate:
```bash
docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d domain1.com -d domain2.com
```

### Wildcard Certificates

Requires DNS-01 challenge (not supported in current setup).
Use separate certbot configuration with DNS plugin.

## Monitoring

### Certificate Expiry Monitoring

```bash
# Check certificate validity
docker compose exec certbot certbot certificates

# Should show:
#   Expiry Date: [date]
#   Days until expiry: [number]
```

### Renewal Logs

```bash
# View renewal attempts
./mintfv.sh logs certbot

# Check for successful renewals
grep "renewed" certbot/logs/letsencrypt.log
```

## Manual Operations

### Force Certificate Request

```bash
# Remove existing certificates
rm -rf certbot/conf/live/your-domain/*

# Request new certificate
./mintfv.sh request-cert
```

### Test Renewal Without Actually Renewing

```bash
docker compose exec certbot certbot renew --dry-run
```

### Revoke Certificate

```bash
docker compose exec certbot certbot revoke \
  --cert-path /etc/letsencrypt/live/your-domain/cert.pem
```

## References

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
