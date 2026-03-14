#!/bin/bash
# =============================================================================
# Mosquitto MQTT User & ACL Management Script
# =============================================================================
# Manages MQTT users and basic ACL entries without restarting the broker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWD_FILE="${SCRIPT_DIR}/mosquitto/config/mosquitto.passwd"
ACL_FILE="${SCRIPT_DIR}/mosquitto/config/mosquitto.acl"
CONTAINER_PASSWD="/tmp/mosquitto.passwd"  # mounted rw in mosquitto-admin

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1" >&2; }

ensure_files_exist() {
    if [ ! -f "$PASSWD_FILE" ]; then
        log_warn "Passwd file missing, creating empty one..."
        : > "$PASSWD_FILE"
    fi
    if [ ! -f "$ACL_FILE" ]; then
        log_warn "ACL file missing, creating empty one..."
        : > "$ACL_FILE"
    fi
}

check_container() {
    if ! docker compose ps --status=running -q mosquitto-admin | grep -q .; then
        log_warn "mosquitto-admin container not running, starting it..."
        docker compose up -d mosquitto-admin
        sleep 2
    fi
}

reload_mosquitto() {
    log_info "Reloading Mosquitto broker (sending HUP signal)..."
    if docker compose kill -s HUP mosquitto >/dev/null 2>&1; then
        log_info "Reload signal sent successfully"
    else
        log_warn "Could not send HUP signal. Mosquitto may need a restart."
    fi
}

add_acl_entry() {
    local username=$1
    if grep -q "^user ${username}$" "$ACL_FILE"; then
        log_warn "ACL entry for user '$username' already exists. Skipping ACL addition."
        return
    fi

    log_info "Adding default ACL entries for user: $username"
    # Detect tenant pattern or use a default
    local tenant_id="de-hh-privat-peddy"
    
    cat >> "$ACL_FILE" <<EOF

# Added via script: $(date "+%Y-%m-%d %H:%M:%S")
user ${username}
topic write umweltbox/${tenant_id}/${username}/#
topic read umweltbox/${tenant_id}/${username}/commands/#
topic read \$SYS/broker/version
EOF
}

remove_acl_entry() {
    local username=$1
    if ! grep -q "^user ${username}$" "$ACL_FILE"; then
        log_warn "No ACL entry found for user '$username'."
        return
    fi

    log_info "Removing ACL entries for user: $username"
    local tmp_acl=$(mktemp)
    
    awk -v user="user ${username}" '
        BEGIN { skip=0 }
        {
            buffer[NR] = $0
        }
        END {
            for (i=1; i<=NR; i++) {
                if (buffer[i] == user) {
                    delete buffer[i]
                    # Check if previous line was a script comment (flexible match for date/time)
                    if (buffer[i-1] ~ /^# Added via script:/) delete buffer[i-1]
                    
                    j = i + 1
                    while (j <= NR && buffer[j] ~ /^\s*topic /) {
                        delete buffer[j]
                        j++
                    }
                }
            }
            for (i=1; i<=NR; i++) {
                if (i in buffer) print buffer[i]
            }
        }
    ' "$ACL_FILE" > "$tmp_acl"
    
    mv "$tmp_acl" "$ACL_FILE"
    
    # Clean up excessive blank lines
    local clean_acl=$(mktemp)
    sed '/^$/N;/^\n$/D' "$ACL_FILE" > "$clean_acl"
    mv "$clean_acl" "$ACL_FILE"
    
    log_info "ACL entries for '$username' removed."
}

cmd_add() {
    local username=$1 password=$2
    [ -z "$username" ] || [ -z "$password" ] && { log_error "Usage: $0 add <username> <password>"; exit 1; }
    [[ "$username" =~ ^[a-zA-Z0-9._-]+$ ]] || { log_error "Invalid username format."; exit 1; }

    ensure_files_exist
    check_container

    log_info "Adding user: $username"
    if docker compose exec -T mosquitto-admin mosquitto_passwd -b "$CONTAINER_PASSWD" "$username" "$password" >/dev/null 2>&1; then
        log_info "User '$username' added/updated in passwd file"
        add_acl_entry "$username"
        reload_mosquitto
    else
        log_error "Failed to add user"
        exit 1
    fi
}

cmd_delete() {
    local username=$1
    [ -z "$username" ] && { log_error "Usage: $0 delete <username>"; exit 1; }

    ensure_files_exist
    check_container

    if ! grep -q "^${username}:" "$PASSWD_FILE" 2>/dev/null; then
        log_error "User '$username' does not exist"
        exit 1
    fi

    log_info "Deleting user: $username"
    if docker compose exec -T mosquitto-admin mosquitto_passwd -D "$CONTAINER_PASSWD" "$username" >/dev/null 2>&1; then
        log_info "User '$username' deleted from passwd file"
        remove_acl_entry "$username"
        reload_mosquitto
    else
        log_error "Failed to delete user"
        exit 1
    fi
}

cmd_list() {
    ensure_files_exist
    echo ""
    echo "Registered MQTT Users:"
    echo "======================"
    cut -d: -f1 "$PASSWD_FILE" | nl
    echo ""
}

cmd_change_password() {
    local username=$1
    [ -z "$username" ] && { log_error "Usage: $0 change-password <username>"; exit 1; }
    ensure_files_exist
    grep -q "^${username}:" "$PASSWD_FILE" 2>/dev/null || { log_error "User '$username' does not exist"; exit 1; }

    read -sp "Enter new password for '$username': " password; echo ""
    read -sp "Confirm password: " password_confirm; echo ""
    [ "$password" = "$password_confirm" ] || { log_error "Passwords do not match"; exit 1; }

    check_container
    log_info "Changing password for user: $username"
    if docker compose exec -T mosquitto-admin mosquitto_passwd -b "$CONTAINER_PASSWD" "$username" "$password" >/dev/null 2>&1; then
        log_info "Password for '$username' changed"
        reload_mosquitto
    else
        log_error "Failed to change password"
        exit 1
    fi
}

cmd_help() {
cat <<'EOF'
Mosquitto MQTT User & ACL Management Script

Usage:
  ./manage_mqtt_users.sh <command> [arguments]

Commands:
  add <username> <password>         Add or update a user (and add default ACLs)
  delete <username>                 Delete a user (and remove ACL entries)
  list                              List all registered users
  change-password <username>        Change password interactively
  help                              Show this help message

Notes:
  - Uses mosquitto-admin container to run mosquitto_passwd
  - Passwd file is mounted rw at /tmp/mosquitto.passwd in mosquitto-admin
  - ACL entries are appended to mosquitto.acl if they don't exist
  - Broker reloads via HUP (no restart needed)
EOF
}

# Main
COMMAND="${1:-help}"
case "$COMMAND" in
  add) cmd_add "$2" "$3" ;;
  delete) cmd_delete "$2" ;;
  list) cmd_list ;;
  change-password) cmd_change_password "$2" ;;
  help) cmd_help ;;
  *) log_error "Unknown command: $COMMAND"; cmd_help; exit 1 ;;
esac

exit 0
