import os
import sys

# Ensure the `selfservice` package is importable when tests run from repo root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import app.config as appcfg
from app import create_app


def test_health_endpoint():
    # Use in-memory SQLite for tests to avoid filesystem permission issues
    appcfg.Config.SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"

    app = create_app()
    with app.test_client() as client:
        resp = client.get('/selfservice/health')
        assert resp.status_code == 200
        assert resp.get_json() == {'status': 'ok'}
