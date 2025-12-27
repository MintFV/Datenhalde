# Backup Strategy for MintFV

This document describes what data needs to be backed up and how to do it using rsync.

## What to Backup

### Critical Data (Must Backup)

1. **SSL Certificates** (`certbot/conf/`)
   - Let's Encrypt certificates
   - Private keys
   - Renewal configurations
   - **Important**: Without backup, you'll need to request new certificates

2. **Configuration Files**
   - `config.yaml` - Your configuration
   - `docker-compose.yaml` - Service definitions (if customized)
   - `nginx/conf/*.conf` - Custom nginx configurations

### Important Data (Should Backup)

3. **Logs** (optional, useful for troubleshooting)
   - `nginx/logs/` - Access and error logs
   - `certbot/logs/` - Certificate renewal logs

4. **Web Content**
   - `nginx/html/` - Custom website files

### Future Data (When Services Active)

5. **Database Data** (future)
   - `influxdb/data/` - Time series data
   - `influxdb/config/` - InfluxDB configuration

6. **Application Data** (future)
   - `nodered/data/` - Node-RED flows and configurations
   - `grafana/data/` - Dashboards and settings
   - `mosquitto/data/` - MQTT persistence

## Backup Schedule

### Critical Data
- **Frequency**: Daily
- **Retention**: 30 days minimum
- **Priority**: High

### Logs
- **Frequency**: Weekly
- **Retention**: 7 days
- **Priority**: Low

### Database/Application Data
- **Frequency**: Daily
- **Retention**: 14-30 days
- **Priority**: High

## Backup Methods

### Using rsync

#### Setup Remote Backup Server

```bash
# On backup server, create backup user and directory
sudo useradd -m -s /bin/bash backup
sudo mkdir -p /backup/mintfv
sudo chown backup:backup /backup/mintfv
```

#### SSH Key Setup

```bash
# On MintFV server
ssh-keygen -t ed25519 -f ~/.ssh/backup_key -N ""
ssh-copy-id -i ~/.ssh/backup_key.pub backup@backup-server
```

#### Backup Script

Create `backup.sh`:

```bash
#!/bin/bash
# MintFV Backup Script

set -e

BACKUP_SERVER="backup@backup-server"
BACKUP_PATH="/backup/mintfv"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SSH_KEY="$HOME/.ssh/backup_key"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Critical data backup
backup_critical() {
    log "Backing up critical data..."
    
    # SSL Certificates
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        ./certbot/conf/ \
        $BACKUP_SERVER:$BACKUP_PATH/certbot-conf/
    
    # Configuration files
    rsync -avz \
        -e "ssh -i $SSH_KEY" \
        --include="*.yaml" \
        --include="*.conf" \
        --exclude="*" \
        ./ \
        $BACKUP_SERVER:$BACKUP_PATH/config/
    
    log "Critical data backup complete"
}

# Log backup
backup_logs() {
    log "Backing up logs..."
    
    rsync -avz \
        -e "ssh -i $SSH_KEY" \
        --exclude="*.gz" \
        ./nginx/logs/ \
        $BACKUP_SERVER:$BACKUP_PATH/logs/nginx/
    
    rsync -avz \
        -e "ssh -i $SSH_KEY" \
        ./certbot/logs/ \
        $BACKUP_SERVER:$BACKUP_PATH/logs/certbot/
    
    log "Log backup complete"
}

# Future: Database backup
backup_databases() {
    log "Backing up databases..."
    
    # InfluxDB
    if [ -d "./influxdb/data" ]; then
        rsync -avz --delete \
            -e "ssh -i $SSH_KEY" \
            ./influxdb/data/ \
            $BACKUP_SERVER:$BACKUP_PATH/influxdb-data/
    fi
    
    log "Database backup complete"
}

# Main backup function
main() {
    log "=== MintFV Backup Started ==="
    
    backup_critical
    backup_logs
    # backup_databases  # Uncomment when databases are active
    
    log "=== MintFV Backup Complete ==="
}

main "$@"
```

Make executable:
```bash
chmod +x backup.sh
```

#### Automated Daily Backup

Add to crontab:
```bash
crontab -e
```

Add line:
```cron
# Daily backup at 2 AM
0 2 * * * cd /home/peddy/mintfv && ./backup.sh >> /var/log/mintfv-backup.log 2>&1
```

### Local Backup

For local backups to external drive:

```bash
#!/bin/bash
# Local backup to external drive

BACKUP_DIR="/mnt/external/mintfv-backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# Backup critical data
rsync -av certbot/conf/ "$BACKUP_DIR/$TIMESTAMP/certbot-conf/"
rsync -av config.yaml docker-compose.yaml "$BACKUP_DIR/$TIMESTAMP/"
rsync -av nginx/conf/ "$BACKUP_DIR/$TIMESTAMP/nginx-conf/"

# Create compressed archive
tar -czf "$BACKUP_DIR/mintfv-$TIMESTAMP.tar.gz" -C "$BACKUP_DIR" "$TIMESTAMP"
rm -rf "$BACKUP_DIR/$TIMESTAMP"

# Keep only last 30 days
find "$BACKUP_DIR" -name "mintfv-*.tar.gz" -mtime +30 -delete
```

## Restore Procedures

### Restore SSL Certificates

```bash
# Stop services
./mintfv.sh stop

# Restore certificates
rsync -av backup@backup-server:/backup/mintfv/certbot-conf/ ./certbot/conf/

# Fix permissions
chmod -R 750 certbot/conf/live
chmod -R 640 certbot/conf/live/*/*.pem

# Start services
./mintfv.sh start
```

### Restore Configuration

```bash
# Restore config files
rsync -av backup@backup-server:/backup/mintfv/config/ ./

# Restart with new configuration
./mintfv.sh restart
```

### Full System Restore

```bash
# 1. Install Docker and Docker Compose
# 2. Clone or restore MintFV directory
# 3. Restore all data

rsync -av backup@backup-server:/backup/mintfv/certbot-conf/ ./certbot/conf/
rsync -av backup@backup-server:/backup/mintfv/config/ ./
rsync -av backup@backup-server:/backup/mintfv/nginx-conf/ ./nginx/conf/

# 4. Fix permissions
chmod 770 nginx/logs certbot/logs

# 5. Start services
./mintfv.sh start
```

## Backup Verification

### Test Restore Procedure

Periodically test restore:

```bash
# Create test directory
mkdir -p /tmp/restore-test
cd /tmp/restore-test

# Restore backup
rsync -av backup@backup-server:/backup/mintfv/ ./

# Verify critical files exist
test -f certbot-conf/live/your-domain/fullchain.pem && echo "Certificates OK"
test -f config/config.yaml && echo "Config OK"
```

### Monitor Backup Size

```bash
# Check backup size trends
ssh backup@backup-server "du -sh /backup/mintfv/*"
```

### Verify Backups Ran

```bash
# Check backup log
tail -50 /var/log/mintfv-backup.log

# Check last backup time
ssh backup@backup-server "ls -lht /backup/mintfv/ | head -5"
```

## Backup Security

### Encryption

For sensitive data, encrypt before transfer:

```bash
# Encrypt certificates before backup
tar -czf - certbot/conf/ | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -out backup-encrypted.tar.gz.enc
```

### Access Control

- Use SSH keys instead of passwords
- Restrict SSH key to rsync command only
- Use separate backup user with limited permissions

### Off-Site Backup

Consider multiple backup locations:
1. Local backup (external drive)
2. Remote backup (different server)
3. Cloud backup (encrypted)

## Disaster Recovery Plan

### Scenario 1: Certificate Lost

```bash
# Stop services
./mintfv.sh stop

# Clean certificate directory
rm -rf certbot/conf/live/* certbot/conf/archive/*

# Request new certificates
./mintfv.sh init
./mintfv.sh request-cert
./mintfv.sh enable-ssl
```

### Scenario 2: Complete Server Loss

1. Provision new server
2. Install Docker and Docker Compose
3. Clone MintFV repository
4. Restore from backup (see "Full System Restore")
5. Update DNS if IP changed
6. Start services

### Scenario 3: Corrupted Data

1. Stop affected services
2. Restore from last known good backup
3. Verify data integrity
4. Restart services

## Monitoring Backup Health

### Backup Monitoring Script

```bash
#!/bin/bash
# Check if backup is current

BACKUP_SERVER="backup@backup-server"
BACKUP_PATH="/backup/mintfv"
MAX_AGE_HOURS=48

LAST_BACKUP=$(ssh $BACKUP_SERVER "stat -c %Y $BACKUP_PATH/certbot-conf")
CURRENT_TIME=$(date +%s)
AGE_HOURS=$(( ($CURRENT_TIME - $LAST_BACKUP) / 3600 ))

if [ $AGE_HOURS -gt $MAX_AGE_HOURS ]; then
    echo "WARNING: Backup is $AGE_HOURS hours old (max: $MAX_AGE_HOURS)"
    exit 1
else
    echo "OK: Backup is $AGE_HOURS hours old"
    exit 0
fi
```

## What NOT to Backup

- Container images (rebuild from Docker Hub)
- Temporary files in `certbot/www/`
- Docker volumes (recreated automatically)
- Log rotated files (`*.gz`)
- `.env.generated` (regenerated from config.yaml)

## Retention Policy

### Production Recommendation

- **Daily backups**: Keep 30 days
- **Weekly backups**: Keep 12 weeks
- **Monthly backups**: Keep 12 months
- **Yearly backups**: Keep 3 years

### Implementation

```bash
# In backup script
# Daily retention (30 days)
find $BACKUP_PATH/daily -mtime +30 -delete

# Weekly retention (84 days = 12 weeks)
find $BACKUP_PATH/weekly -mtime +84 -delete

# Monthly retention (365 days)
find $BACKUP_PATH/monthly -mtime +365 -delete
```

## Cloud Backup Options

### Rclone to Cloud Storage

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure cloud storage (example: Google Drive)
rclone config

# Backup to cloud
rclone sync /local/backup remote:mintfv-backup
```

### Automated Cloud Backup

```bash
# Add to backup script
rclone sync --progress \
    /local/backup/mintfv \
    remote:mintfv-backup \
    --exclude "*.log"
```

## Compliance & Legal

Depending on data being stored:
- Check data retention legal requirements
- Implement appropriate encryption
- Document backup procedures
- Regular restore testing
- Audit backup access logs

## References

- [rsync Documentation](https://rsync.samba.org/)
- [Docker Volume Backup](https://docs.docker.com/storage/volumes/#back-up-restore-or-migrate-data-volumes)
- [rclone Documentation](https://rclone.org/docs/)
