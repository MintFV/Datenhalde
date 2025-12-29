#!/bin/bash
# MintFV Management Script
# Init.d-style control script for Docker Compose services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE=".env"
COMPOSE_FILE="docker-compose.yaml"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    if ! command -v docker &> /dev/null; then
        log_error "docker not found. Please install Docker first."
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        log_error "docker compose not found. Please install Docker Compose plugin."
        exit 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file $CONFIG_FILE not found."
        log_info "Please copy env.example to .env and adjust the values."
        exit 1
    fi
}

load_config() {
    # Load from .env file
    if [ -f "$CONFIG_FILE" ]; then
        # Export all variables from .env
        set -a
        source "$CONFIG_FILE"
        set +a
    else
        log_error ".env file not found"
        exit 1
    fi

    # Validate required variables
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        log_error "DOMAIN and EMAIL must be set in $CONFIG_FILE"
        exit 1
    fi

    log_info "Configuration loaded:"
    log_info "  Domain: $DOMAIN"
    log_info "  Email: $EMAIL"
    log_info "  Timezone: $TZ"
}

init_directories() {
    log_info "Initializing directory structure..."

    # Create required directories
    mkdir -p nginx/{conf,html,logs}
    mkdir -p certbot/{conf,www,logs}

    # Set permissions for log directories
    chmod 770 nginx/logs certbot/logs 2>/dev/null || true

    log_info "Directory structure created"
}

init_ssl() {
    log_info "Initializing SSL certificates..."

    log_info "Using Let's Encrypt PRODUCTION environment"

    # Start certbot-init to create dummy certificates
    docker compose up -d certbot-init

    log_info "Waiting for certificate initialization..."
    sleep 5

    # Check if initialization was successful
    if docker compose ps certbot-init | grep -q "healthy"; then
        log_info "✓ Dummy certificates created successfully"
    else
        log_error "Certificate initialization failed"
        docker compose logs certbot-init
        exit 1
    fi
}

request_real_certificate() {
    log_info "Requesting real SSL certificate from Let's Encrypt..."

    # Request certificate using webroot method
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" || {
        log_error "Certificate request failed"
        log_info "Check if:"
        log_info "  1. Domain $DOMAIN points to this server"
        log_info "  2. Port 80 is accessible from the internet"
        log_info "  3. nginx is running and healthy"
        return 1
    }

    log_info "✓ Real certificate obtained successfully"
}

enable_ssl() {
    log_info "Enabling SSL configuration..."

    # Create ssl.conf from template
    if [ -f nginx/conf/ssl.conf.example ]; then
        sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/conf/ssl.conf.example > nginx/conf/ssl.conf

        # Backup default.conf
        if [ -f nginx/conf/default.conf ]; then
            mv nginx/conf/default.conf nginx/conf/default.conf.disabled
            log_info "HTTP-only config disabled"
        fi

        log_info "✓ SSL configuration enabled"
    else
        log_error "SSL template not found: nginx/conf/ssl.conf.example"
        return 1
    fi
}

disable_ssl() {
    log_info "Disabling SSL configuration..."

    # Restore default.conf
    if [ -f nginx/conf/default.conf.disabled ]; then
        mv nginx/conf/default.conf.disabled nginx/conf/default.conf
    fi

    # Remove ssl.conf
    if [ -f nginx/conf/ssl.conf ]; then
        mv nginx/conf/ssl.conf nginx/conf/ssl.conf.disabled
    fi

    log_info "✓ SSL configuration disabled (HTTP only)"
}

start_services() {
    log_info "Starting MintFV services..."
    docker compose up -d

    log_info "Waiting for services to become healthy..."
    sleep 10

    docker compose ps
}

stop_services() {
    log_info "Stopping MintFV services..."
    docker compose down
    log_info "✓ Services stopped"
}

restart_services() {
    log_info "Restarting MintFV services..."
    docker compose restart
    log_info "✓ Services restarted"
}

show_status() {
    log_info "Service Status:"
    docker compose ps
    echo ""

    log_info "Health Checks:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}"
    echo ""
    log_info "Currently using Let's Encrypt PRODUCTION environment"
}

show_logs() {
    local service="${1:-}"
    if [ -z "$service" ]; then
        docker compose logs -f
    else
        docker compose logs -f "$service"
    fi
}


cleanup() {
    log_warn "=== Cleanup ==="
    log_warn "This will remove all containers, volumes, and generated data"
    echo ""
    read -p "Are you sure? (yes/no): " -r

    if [ "$REPLY" != "yes" ]; then
        log_info "Cleanup cancelled"
        return 0
    fi

    log_info "Stopping and removing containers..."
    docker compose down -v

    log_info "Removing generated files..."
    rm -rf certbot/conf/* certbot/logs/* nginx/logs/* 2>/dev/null || true

    log_info "✓ Cleanup complete"
}

show_usage() {
    cat << EOF
MintFV Management Script

Usage: $0 {command} [options]

Commands:
    init                Initialize directory structure and SSL certificates
    start               Start all services
    stop                Stop all services
    restart             Restart all services
    status              Show service status
    logs [service]      Show logs (optional: specific service)

    request-cert        Request real SSL certificate from Let's Encrypt
    enable-ssl          Enable HTTPS (switches nginx to SSL config)
    disable-ssl         Disable HTTPS (switches nginx to HTTP-only config)

    cleanup             Remove all containers and data (destructive!)

Examples:
    $0 init             # First-time setup
    $0 start            # Start all services
    $0 status           # Check service status
    $0 logs nginx       # Show nginx logs

Configuration:
    Edit config.yaml to change domain, email, and other settings

EOF
}

# Main command handler
main() {
    local command="${1:-}"

    case "$command" in
        init)
            check_requirements
            load_config
            init_directories
            init_ssl
            start_services
            log_info ""
            log_info "=== Initialization Complete ==="
            log_info "Services are running with dummy SSL certificates"
            log_info ""
            log_info "Next steps:"
            log_info "  1. Verify nginx is accessible: http://$DOMAIN"
            log_info "  2. Request real certificate: $0 request-cert"
            log_info "  3. Enable HTTPS: $0 enable-ssl"
            ;;

        start)
            check_requirements
            load_config
            start_services
            ;;

        stop)
            stop_services
            ;;

        restart)
            restart_services
            ;;

        status)
            show_status
            ;;

        logs)
            show_logs "${2:-}"
            ;;

        request-cert)
            check_requirements
            load_config
            request_real_certificate
            ;;

        enable-ssl)
            check_requirements
            load_config
            enable_ssl
            restart_services
            ;;

        disable-ssl)
            disable_ssl
            restart_services
            ;;

        cleanup)
            cleanup
            ;;

        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
