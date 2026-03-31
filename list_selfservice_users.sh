#!/usr/bin/env bash
# MintFV Selfservice – Benutzerverwaltung
# Nutzung: ./list_selfservice_users.sh [Befehl] [Argumente]
#
# Befehle:
#   list                         Alle Benutzer anzeigen (Standard)
#   search <pattern>             Benutzer nach E-Mail/Name suchen
#   add <email> <name> <pass>    Neuen Benutzer anlegen
#   delete <id>                  Benutzer anhand ID löschen
#   toggle-verify <id>           E-Mail-Verifikation ein-/ausschalten
#   change-email <id> <email>    E-Mail-Adresse ändern

set -euo pipefail

COMPOSE_FILE="$(cd "$(dirname "$0")" && pwd)/docker-compose.yaml"
CMD="${1:-list}"

# Hilfsfunktion: Python im Container ausführen
run_py() {
    docker compose -f "$COMPOSE_FILE" exec -T selfservice python3 -c "$1" \
        2>/dev/null | grep -v "^WARN\|UserWarning\|warnings.warn\|flask_limiter"
}

# --- list ----------------------------------------------------------------
cmd_list() {
    echo "=== MintFV Selfservice – Benutzerübersicht ==="
    echo ""
    run_py "
from app import create_app
from app.models import User
app = create_app()
with app.app_context():
    users = User.query.order_by(User.created_at).all()
    if not users:
        print('Keine Benutzer vorhanden.')
    else:
        print(f\"{'ID':<5} {'E-Mail':<38} {'Anzeigename':<22} {'Rolle':<8} {'Verifiziert':<12} {'Tenant':<15} {'Erstellt'}\")
        print('-' * 125)
        for u in users:
            tenant_id = u.tenant.tenant_id if u.tenant else '-'
            verified = 'Ja' if u.email_verified else 'Nein'
            created = u.created_at.strftime('%d.%m.%Y %H:%M') if u.created_at else '-'
            print(f'{u.id:<5} {u.email:<38} {u.display_name:<22} {u.role:<8} {verified:<12} {tenant_id:<15} {created}')
        print(f'\nGesamt: {len(users)} Benutzer')
"
}

# --- search --------------------------------------------------------------
cmd_search() {
    local pattern="${1:-}"
    if [[ -z "$pattern" ]]; then
        echo "Fehler: Kein Suchmuster angegeben." >&2
        echo "Nutzung: $0 search <pattern>" >&2
        exit 1
    fi
    echo "=== Suche nach: '$pattern' ==="
    echo ""
    run_py "
from app import create_app
from app.models import User
app = create_app()
with app.app_context():
    users = User.query.filter(
        (User.email.ilike('%${pattern}%')) | (User.display_name.ilike('%${pattern}%'))
    ).order_by(User.created_at).all()
    if not users:
        print('Keine Treffer.')
    else:
        print(f\"{'ID':<5} {'E-Mail':<38} {'Anzeigename':<22} {'Rolle':<8} {'Verifiziert':<12} {'Tenant':<15} {'Erstellt'}\")
        print('-' * 125)
        for u in users:
            tenant_id = u.tenant.tenant_id if u.tenant else '-'
            verified = 'Ja' if u.email_verified else 'Nein'
            created = u.created_at.strftime('%d.%m.%Y %H:%M') if u.created_at else '-'
            print(f'{u.id:<5} {u.email:<38} {u.display_name:<22} {u.role:<8} {verified:<12} {tenant_id:<15} {created}')
        print(f'\nTreffer: {len(users)}')
"
}

# --- add -----------------------------------------------------------------
cmd_add() {
    local email="${1:-}"
    local name="${2:-}"
    local password="${3:-}"
    if [[ -z "$email" || -z "$name" || -z "$password" ]]; then
        echo "Fehler: E-Mail, Anzeigename und Passwort erforderlich." >&2
        echo "Nutzung: $0 add <email> <name> <passwort>" >&2
        exit 1
    fi
    if [[ "${#password}" -lt 8 ]]; then
        echo "Fehler: Passwort muss mindestens 8 Zeichen lang sein." >&2
        exit 1
    fi
    echo "Lege Benutzer '$email' an ..."
    run_py "
from app import create_app
from app.extensions import db
from app.models import User
app = create_app()
with app.app_context():
    if User.query.filter_by(email='${email}'.lower()).first():
        print('FEHLER: E-Mail bereits vorhanden.')
        exit(1)
    u = User(email='${email}'.lower().strip(), display_name='${name}')
    u.set_password('${password}')
    u.email_verified = True
    db.session.add(u)
    db.session.commit()
    print(f'Benutzer erstellt: ID={u.id}, E-Mail={u.email}, Verifikation=Ja')
"
}

# --- delete --------------------------------------------------------------
cmd_delete() {
    local id="${1:-}"
    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
        echo "Fehler: Gültige Benutzer-ID erforderlich." >&2
        echo "Nutzung: $0 delete <id>" >&2
        exit 1
    fi

    # Benutzer anzeigen vor Löschung
    echo "Benutzer mit ID $id:"
    run_py "
from app import create_app
from app.models import User
app = create_app()
with app.app_context():
    u = User.query.get(${id})
    if not u:
        print('FEHLER: Benutzer nicht gefunden.')
        exit(1)
    print(f'  E-Mail:      {u.email}')
    print(f'  Anzeigename: {u.display_name}')
    print(f'  Rolle:       {u.role}')
"
    echo ""
    read -r -p "Benutzer ID $id wirklich löschen? [j/N] " confirm
    if [[ "$confirm" != "j" && "$confirm" != "J" ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    run_py "
from app import create_app
from app.extensions import db
from app.models import User
app = create_app()
with app.app_context():
    u = User.query.get(${id})
    if not u:
        print('FEHLER: Benutzer nicht gefunden.')
        exit(1)
    email = u.email
    db.session.delete(u)
    db.session.commit()
    print(f'Benutzer gelöscht: {email} (ID={id})')
"
}

# --- toggle-verify -------------------------------------------------------
cmd_toggle_verify() {
    local id="${1:-}"
    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
        echo "Fehler: Gültige Benutzer-ID erforderlich." >&2
        echo "Nutzung: $0 toggle-verify <id>" >&2
        exit 1
    fi
    run_py "
from app import create_app
from app.extensions import db
from app.models import User
app = create_app()
with app.app_context():
    u = User.query.get(${id})
    if not u:
        print('FEHLER: Benutzer nicht gefunden.')
        exit(1)
    u.email_verified = not u.email_verified
    db.session.commit()
    status = 'Ja' if u.email_verified else 'Nein'
    print(f'Benutzer {u.email} (ID={u.id}): E-Mail-Verifikation → {status}')
"
}

# --- change-email --------------------------------------------------------
cmd_change_email() {
    local id="${1:-}"
    local new_email="${2:-}"
    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ || -z "$new_email" ]]; then
        echo "Fehler: Benutzer-ID und neue E-Mail erforderlich." >&2
        echo "Nutzung: $0 change-email <id> <neue-email>" >&2
        exit 1
    fi
    run_py "
from app import create_app
from app.extensions import db
from app.models import User
app = create_app()
with app.app_context():
    u = User.query.get(${id})
    if not u:
        print('FEHLER: Benutzer nicht gefunden.')
        exit(1)
    new_email = '${new_email}'.lower().strip()
    if User.query.filter(User.email == new_email, User.id != ${id}).first():
        print(f'FEHLER: E-Mail {new_email} ist bereits vergeben.')
        exit(1)
    old_email = u.email
    u.email = new_email
    u.email_verified = False
    db.session.commit()
    print(f'E-Mail geändert: {old_email} → {new_email} (ID={u.id})')
    print('Hinweis: Verifikation wurde zurückgesetzt (Nein). Ggf. toggle-verify ausführen.')
"
}

# --- usage ---------------------------------------------------------------
cmd_usage() {
    echo "Nutzung: $0 [Befehl] [Argumente]"
    echo ""
    echo "Befehle:"
    echo "  list                           Alle Benutzer anzeigen (Standard)"
    echo "  search <pattern>               Benutzer nach E-Mail/Name suchen"
    echo "  add <email> <name> <passwort>  Neuen Benutzer anlegen (verifiziert)"
    echo "  delete <id>                    Benutzer anhand ID löschen"
    echo "  toggle-verify <id>             E-Mail-Verifikation ein-/ausschalten"
    echo "  change-email <id> <email>      E-Mail-Adresse ändern (setzt Verifikation zurück)"
    echo "  help                           Diese Hilfe anzeigen"
}

# --- Dispatcher ----------------------------------------------------------
case "$CMD" in
    list)           cmd_list ;;
    search)         cmd_search "${2:-}" ;;
    add)            cmd_add "${2:-}" "${3:-}" "${4:-}" ;;
    delete)         cmd_delete "${2:-}" ;;
    toggle-verify)  cmd_toggle_verify "${2:-}" ;;
    change-email)   cmd_change_email "${2:-}" "${3:-}" ;;
    help|--help|-h) cmd_usage ;;
    *)
        echo "Unbekannter Befehl: '$CMD'" >&2
        echo ""
        cmd_usage >&2
        exit 1
        ;;
esac

