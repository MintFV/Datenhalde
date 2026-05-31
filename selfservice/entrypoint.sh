#!/bin/sh
set -e

echo "=== MintFV Selfservice ==="

# Datenbank-Migrationen ausführen
echo "Running database migrations..."
DB_FILE="/app/data/selfservice.db"
if [ -f "$DB_FILE" ]; then
    # Prüfe ob alembic_version-Tabelle existiert (= bereits gemanagt)
    if ! sqlite3 "$DB_FILE" "SELECT 1 FROM alembic_version LIMIT 1" 2>/dev/null; then
        echo "Existing DB without migration history — stamping current revision..."
        flask --app 'app:create_app()' db stamp head
    fi
fi
flask --app 'app:create_app()' db upgrade
echo "Migrations complete."

echo "Starting gunicorn on port 5000..."

exec gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    "app:create_app()"
