#!/bin/bash
# =============================================================================
# Mosquitto MQTT User Management Script
# =============================================================================
# Manages MQTT user passwords without restarting the broker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWD_FILE="${SCRIPT_DIR}/mosquitto/config/mosquitto.passwd"
CONTAINER_PASSWD="/tmp/mosquitto.passwd"  # mounted rw in mosquitto-admin

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1" >&2; }

ensure_passwd_exists() {
    if [ ! -f "$PASSWD_FILE" ]; then
        log_warn "Passwd file missing, creating empty one..."
        : > "$PASSWD_FILE"
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

cmd_add() {
    local username=$1 password=$2
    [ -z "$username" ] || [ -z "$password" ] && { log_error "Usage: $0 add <username> <password>"; exit 1; }
    [[ "$username" =~ ^[a-zA-Z0-9._-]+$ ]] || { log_error "Invalid username format."; exit 1; }

    ensure_passwd_exists
    check_container

    log_info "Adding user: $username"
    if docker compose exec -T mosquitto-admin mosquitto_passwd -b "$CONTAINER_PASSWD" "$username" "$password" >/dev/null 2>&1; then
        log_info "User '$username' added/updated"
        reload_mosquitto
    else
        log_error "Failed to add user"
        exit 1
    fi
}

cmd_delete() {
    local username=$1
    [ -z "$username" ] && { log_error "Usage: $0 delete <username>"; exit 1; }

    ensure_passwd_exists
    check_container

    if ! grep -q "^${username}:" "$PASSWD_FILE" 2>/dev/null; then
        log_error "User '$username' does not exist"
        exit 1
    fi

    log_info "Deleting user: $username"
    if docker compose exec -T mosquitto-admin mosquitto_passwd -D "$CONTAINER_PASSWD" "$username" >/dev/null 2>&1; then
        log_info "User '$username' deleted"
        reload_mosquitto
    else
        log_error "Failed to delete user"
        exit 1
    fi
}

cmd_list() {
    ensure_passwd_exists
    echo ""
    echo "Registered MQTT Users:"
    echo "======================"
    cut -d: -f1 "$PASSWD_FILE" | nl
    echo ""
}

cmd_change_password() {
    local username=$1
    [ -z "$username" ] && { log_error "Usage: $0 change-password <username>"; exit 1; }
    ensure_passwd_exists
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
Mosquitto MQTT User Management Script

Usage:
  ./manage_mqtt_users.sh <command> [arguments]

Commands:
  add <username> <password>         Add or update a user
  delete <username>                 Delete a user
  list                              List all registered users
  change-password <username>        Change password interactively
  help                              Show this help message

Notes:
  - Uses mosquitto-admin container to run mosquitto_passwd
  - Passwd file is mounted rw at /tmp/mosquitto.passwd in mosquitto-admin
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