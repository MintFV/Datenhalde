import os
import sys

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import app.config as appcfg
from app import create_app
from app.extensions import db as _db
from app.models import User


@pytest.fixture()
def test_app(tmp_path, monkeypatch):
    monkeypatch.setattr(appcfg.Config, "SQLALCHEMY_DATABASE_URI", "sqlite:///:memory:")
    app = create_app()
    app.config.update(
        TESTING=True,
        WTF_CSRF_ENABLED=False,
        SQLALCHEMY_DATABASE_URI="sqlite:///:memory:",
        SECRET_KEY="test-secret",
        DOMAIN="example.test",
        MOSQUITTO_PASSWD_FILE=str(tmp_path / "mosquitto.passwd"),
        MOSQUITTO_ACL_FILE=str(tmp_path / "mosquitto.acl"),
        MOSQUITTO_RELOAD_DIR=str(tmp_path / "reload"),
    )
    (tmp_path / "mosquitto.passwd").write_text("", encoding="utf-8")
    (tmp_path / "mosquitto.acl").write_text("", encoding="utf-8")
    (tmp_path / "reload").mkdir()

    with app.app_context():
        _db.create_all()

    yield app

    with app.app_context():
        _db.session.remove()
        _db.drop_all()


@pytest.fixture()
def client(test_app):
    return test_app.test_client()


@pytest.fixture()
def make_user(test_app):
    def factory(email: str, role: str = "user", tenant_id: int | None = None) -> int:
        with test_app.app_context():
            user = User(
                email=email,
                display_name=email.split("@")[0],
                role=role,
                tenant_id=tenant_id,
            )
            user.set_password("password123")
            _db.session.add(user)
            _db.session.commit()
            return int(user.id)

    return factory


@pytest.fixture()
def login(client):
    def factory(user_id: int) -> None:
        with client.session_transaction() as session:
            session["_user_id"] = str(user_id)
            session["_fresh"] = True

    return factory
