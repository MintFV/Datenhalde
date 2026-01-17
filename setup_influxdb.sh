#!/bin/bash
#
# InfluxDB 3 Core Setup Script für MintFV
# Erstellt Datenbanken, Tokens und prüft die Konfiguration
#

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktionen
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Token aus Container holen
get_token() {
    docker compose exec influxdb cat /var/lib/influxdb3/tokens/admin.token | jq -r '.token'
}

# Prüfen ob InfluxDB läuft
check_influxdb() {
    info "Prüfe InfluxDB Status..."
    if ! docker compose ps influxdb | grep -q "Up"; then
        error "InfluxDB Container läuft nicht!"
        exit 1
    fi
    info "InfluxDB läuft ✓"
}

# Datenbanken anzeigen
show_databases() {
    info "Vorhandene Datenbanken:"
    TOKEN=$(get_token)
    docker compose exec influxdb influxdb3 show databases \
        --host http://localhost:8181 \
        --token "$TOKEN"
}

# Datenbank erstellen
create_database() {
    local DB_NAME=$1
    info "Erstelle Datenbank: $DB_NAME"
    TOKEN=$(get_token)
    
    docker compose exec influxdb influxdb3 create database \
        --host http://localhost:8181 \
        --token "$TOKEN" \
        "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        info "Datenbank '$DB_NAME' erfolgreich erstellt ✓"
    else
        warn "Datenbank '$DB_NAME' existiert bereits oder Fehler beim Erstellen"
    fi
}

# Token erstellen
create_token() {
    local TOKEN_NAME=$1
    local PERMISSIONS=$2
    info "Erstelle Token: $TOKEN_NAME mit Permissions: $PERMISSIONS"
    TOKEN=$(get_token)
    
    docker compose exec influxdb influxdb3 create token \
        --host http://localhost:8181 \
        --token "$TOKEN" \
        --name "$TOKEN_NAME" \
        --permissions "$PERMISSIONS"
}

# Tokens anzeigen
show_tokens() {
    info "Vorhandene Tokens:"
    TOKEN=$(get_token)
    docker compose exec influxdb influxdb3 show tokens \
        --host http://localhost:8181 \
        --token "$TOKEN"
}

# Tabellen in Datenbank anzeigen
show_tables() {
    local DB_NAME=$1
    info "Tabellen in Datenbank '$DB_NAME':"
    TOKEN=$(get_token)
    docker compose exec influxdb influxdb3 query \
        --database "$DB_NAME" \
        --host http://localhost:8181 \
        --token "$TOKEN" \
        "SHOW TABLES"
}

# Daten abfragen
query_data() {
    local DB_NAME=$1
    local TABLE_NAME=$2
    local LIMIT=${3:-10}
    info "Letzte $LIMIT Einträge aus '$DB_NAME.$TABLE_NAME':"
    TOKEN=$(get_token)
    docker compose exec influxdb influxdb3 query \
        --database "$DB_NAME" \
        --host http://localhost:8181 \
        --token "$TOKEN" \
        "SELECT * FROM $TABLE_NAME ORDER BY time DESC LIMIT $LIMIT"
}

# Schema einer Tabelle anzeigen
show_schema() {
    local DB_NAME=$1
    local TABLE_NAME=$2
    info "Schema von '$DB_NAME.$TABLE_NAME':"
    TOKEN=$(get_token)
    docker compose exec influxdb influxdb3 query \
        --database "$DB_NAME" \
        --host http://localhost:8181 \
        --token "$TOKEN" \
        "SELECT * FROM information_schema.columns WHERE table_name = '$TABLE_NAME'"
}

# Hauptmenü
show_menu() {
    echo ""
    echo "========================================="
    echo "  InfluxDB 3 Core Management"
    echo "========================================="
    echo "1) Datenbanken anzeigen"
    echo "2) Datenbank erstellen"
    echo "3) Tokens anzeigen"
    echo "4) Token erstellen"
    echo "5) Tabellen anzeigen"
    echo "6) Daten abfragen"
    echo "7) Schema anzeigen"
    echo "8) Standard-Setup ausführen"
    echo "9) Status-Check"
    echo "0) Beenden"
    echo "========================================="
}

# Standard-Setup
standard_setup() {
    info "Führe Standard-Setup aus..."
    
    # Prüfe ob Standard-Datenbanken existieren
    info "Erstelle Standard-Datenbanken..."
    create_database "mintfv"
    create_database "umweltbox"
    
    info ""
    info "Standard-Setup abgeschlossen!"
    show_databases
}

# Status-Check
status_check() {
    info "=== InfluxDB Status Check ==="
    check_influxdb
    echo ""
    show_databases
    echo ""
    show_tokens
}

# Hauptprogramm
main() {
    check_influxdb
    
    if [ "$1" == "--setup" ]; then
        standard_setup
        exit 0
    fi
    
    if [ "$1" == "--status" ]; then
        status_check
        exit 0
    fi
    
    while true; do
        show_menu
        read -p "Wähle eine Option: " choice
        
        case $choice in
            1)
                show_databases
                ;;
            2)
                read -p "Datenbankname: " db_name
                create_database "$db_name"
                ;;
            3)
                show_tokens
                ;;
            4)
                read -p "Token-Name: " token_name
                read -p "Permissions (z.B. 'mintfv:read:*' oder '*:*:*'): " perms
                create_token "$token_name" "$perms"
                ;;
            5)
                read -p "Datenbankname: " db_name
                show_tables "$db_name"
                ;;
            6)
                read -p "Datenbankname: " db_name
                read -p "Tabellenname: " table_name
                read -p "Limit (default 10): " limit
                query_data "$db_name" "$table_name" "${limit:-10}"
                ;;
            7)
                read -p "Datenbankname: " db_name
                read -p "Tabellenname: " table_name
                show_schema "$db_name" "$table_name"
                ;;
            8)
                standard_setup
                ;;
            9)
                status_check
                ;;
            0)
                info "Auf Wiedersehen!"
                exit 0
                ;;
            *)
                error "Ungültige Auswahl!"
                ;;
        esac
        
        echo ""
        read -p "Drücke Enter um fortzufahren..."
    done
}

main "$@"
