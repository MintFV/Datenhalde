"""Tests für Flask-Mailman Integration."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import app.config as appcfg
from app import create_app


def _make_app():
    """Erstellt Test-App mit In-Memory DB und File-Backend für Mail."""
    appcfg.Config.SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    appcfg.Config.MAIL_BACKEND = "console"  # Kein echtes SMTP nötig
    appcfg.Config.SELFSERVICE_SECRET_KEY = "test-secret"
    appcfg.Config.SECRET_KEY = "test-secret"
    appcfg.Config.DOMAIN = "test.example.com"
    appcfg.Config.WTF_CSRF_ENABLED = False
    application = create_app()
    return application


def test_mail_extension_initialized():
    """Flask-Mailman ist korrekt initialisiert."""
    application = _make_app()
    assert "mailman" in application.extensions


def test_send_email_via_mailman(tmp_path):
    """E-Mail-Versand über Flask-Mailman funktioniert (File-Backend)."""
    appcfg.Config.SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    appcfg.Config.MAIL_BACKEND = "file"
    appcfg.Config.MAIL_FILE_PATH = str(tmp_path)
    appcfg.Config.SECRET_KEY = "test-secret"
    appcfg.Config.DOMAIN = "test.example.com"
    appcfg.Config.WTF_CSRF_ENABLED = False

    application = create_app()

    with application.app_context():
        from app.auth.email import _send_email

        _send_email("user@example.com", "Testbetreff", "<p>Hallo</p>")

    # File-Backend schreibt E-Mails als Dateien
    sent_files = list(tmp_path.iterdir())
    assert len(sent_files) == 1
    content = sent_files[0].read_text()
    assert "Testbetreff" in content
    assert "user@example.com" in content


def test_verification_token_roundtrip():
    """Token-Generierung und -Verifikation funktioniert."""
    application = _make_app()

    with application.app_context():
        from app.auth.email import (
            confirm_verification_token,
            generate_verification_token,
        )

        token = generate_verification_token("test@example.com")
        email = confirm_verification_token(token)
        assert email == "test@example.com"


def test_reset_token_roundtrip():
    """Reset-Token-Generierung und -Verifikation funktioniert."""
    application = _make_app()

    with application.app_context():
        from app.auth.email import confirm_reset_token, generate_reset_token

        token = generate_reset_token("test@example.com")
        email = confirm_reset_token(token)
        assert email == "test@example.com"
