#!/bin/sh
set -e

echo "=== MintFV Selfservice ==="
echo "Starting gunicorn on port 5000..."

exec gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    "app:create_app()"
