"""Tests für Flask-Migrate Integration."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import app.config as appcfg
from app import create_app
from app.extensions import db


def _make_app(tmp_path):
    """Erstellt Test-App mit SQLite-Datei in tmp_path."""
    db_path = str(tmp_path / "test.db")
    appcfg.Config.SQLALCHEMY_DATABASE_URI = f"sqlite:///{db_path}"
    appcfg.Config.SECRET_KEY = "test-secret"
    appcfg.Config.DOMAIN = "test.example.com"
    appcfg.Config.MAIL_BACKEND = "console"
    appcfg.Config.WTF_CSRF_ENABLED = False
    application = create_app()
    return application, db_path


def test_migrate_extension_initialized(tmp_path):
    """Flask-Migrate ist korrekt initialisiert."""
    application, _ = _make_app(tmp_path)
    assert "migrate" in application.extensions


def test_migrations_upgrade_creates_tables(tmp_path):
    """flask db upgrade erstellt alle Tabellen aus der Migration."""
    application, db_path = _make_app(tmp_path)

    with application.app_context():
        from flask_migrate import upgrade

        upgrade()

        # Prüfen, dass Tabellen existiert
        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()
        assert "users" in tables
        assert "tenants" in tables
        assert "mqtt_accounts" in tables
        assert "devices" in tables
        assert "alembic_version" in tables


def test_migrations_are_idempotent(tmp_path):
    """Zweimaliges Ausführen von upgrade ist safe."""
    application, _ = _make_app(tmp_path)

    with application.app_context():
        from flask_migrate import upgrade

        upgrade()
        # Zweiter Aufruf darf keinen Fehler werfen
        upgrade()

        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()
        assert "users" in tables


def test_model_matches_migration(tmp_path):
    """Nach Migration können Models genutzt werden (Insert/Query)."""
    application, _ = _make_app(tmp_path)

    with application.app_context():
        from flask_migrate import upgrade

        upgrade()

        from app.models import User

        user = User(
            email="test@example.com",
            password_hash="fakehash",
            display_name="Test User",
        )
        db.session.add(user)
        db.session.commit()

        found = db.session.execute(
            db.select(User).filter_by(email="test@example.com")
        ).scalar_one()
        assert found.display_name == "Test User"
