import pytest
from flask import render_template, template_rendered

from app.extensions import db
from app.models import Device, MqttAccount, Tenant
from app.mqtt.tasmota import (
    FULL_TOPIC,
    build_tasmota_backlog,
    is_tasmota_password_safe,
)


def test_build_tasmota_backlog():
    result = build_tasmota_backlog(
        domain="mintfv.peddy.net",
        topic="umweltbox/de-hh-gs-test/esp01",
        username="test-sensor",
        password="sicheres-passwort",
        client="esp01",
    )
    assert result == (
        "Backlog0 MqttHost mintfv.peddy.net; MqttPort 8883; MqttUser test-sensor; "
        "MqttPassword sicheres-passwort; MqttClient esp01; "
        "Topic umweltbox/de-hh-gs-test/esp01; "
        "FullTopic umweltbox/%topic%/%prefix%/; SetOption3 1; TelePeriod 300"
    )
    assert FULL_TOPIC == "umweltbox/%topic%/%prefix%/"


@pytest.mark.parametrize(
    "password",
    ["abc;def", 'abc"def', "abc\\def", "abc\ndef", "abc\tdef", "abc\x00def"],
)
def test_unsafe_passwords_are_rejected(password):
    assert not is_tasmota_password_safe(password)
    with pytest.raises(ValueError, match="Backlog"):
        build_tasmota_backlog("host", "topic", "user", password, "client")


@pytest.mark.parametrize(
    "password",
    ["sicheres-passwort", "Xy9#mK2$qL8@vN3!", "abcDEF123!@#"],
)
def test_safe_passwords_are_accepted(password):
    assert is_tasmota_password_safe(password)


def _prepare_tenant(test_app, device_type="tasmota"):
    with test_app.app_context():
        tenant = Tenant(tenant_id="de-hh-gs-test", name="Testschule", status="active")
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id
        if device_type:
            db.session.add(Device(tenant_id=tenant_id, device_id="esp01", device_type=device_type))
            db.session.commit()
    return tenant_id


def _capture_backlog(test_app, client, login, user_id, data, url):
    contexts = []

    def record(sender, template, context, **extra):
        if template.name == "mqtt/credentials.html":
            contexts.append(dict(context))

    login(user_id)
    with template_rendered.connected_to(record, test_app):
        response = client.post(url, data=data, follow_redirects=True)
    return response, contexts[0]["backlog"]


def test_create_tasmota_account_provides_backlog(test_app, client, make_user, login):
    tenant_id = _prepare_tenant(test_app)
    response, backlog = _capture_backlog(
        test_app,
        client,
        login,
        make_user("backlog-owner@example.test", tenant_id=tenant_id),
        {
            "username": "test-sensor-tasmota",
            "role": "sensor",
            "device_id": "esp01",
            "password": "sicheres-passwort",
        },
        "/selfservice/mqtt/erstellen",
    )
    assert response.status_code == 200
    assert backlog == (
        "Backlog0 MqttHost example.test; MqttPort 8883; "
        "MqttUser test-sensor-tasmota; MqttPassword sicheres-passwort; "
        "MqttClient esp01; Topic umweltbox/de-hh-gs-test/esp01; "
        "FullTopic umweltbox/%topic%/%prefix%/; SetOption3 1; TelePeriod 300"
    )


@pytest.mark.parametrize("device_type", ["rpi", "telegraf"])
def test_other_device_types_have_no_backlog(test_app, client, make_user, login, device_type):
    tenant_id = _prepare_tenant(test_app, device_type)
    response, backlog = _capture_backlog(
        test_app,
        client,
        login,
        make_user(f"backlog-{device_type}@example.test", tenant_id=tenant_id),
        {
            "username": f"test-{device_type}",
            "role": "sensor",
            "device_id": "esp01",
            "password": "sicheres-passwort",
        },
        "/selfservice/mqtt/erstellen",
    )
    assert response.status_code == 200
    assert backlog is None


def test_account_without_device_has_no_backlog(test_app, client, make_user, login):
    tenant_id = _prepare_tenant(test_app, device_type=None)
    response, backlog = _capture_backlog(
        test_app,
        client,
        login,
        make_user("backlog-admin@example.test", tenant_id=tenant_id),
        {
            "username": "test-admin",
            "role": "admin",
            "device_id": "",
            "password": "sicheres-passwort",
        },
        "/selfservice/mqtt/erstellen",
    )
    assert response.status_code == 200
    assert backlog is None


def test_unsafe_password_shows_hint_without_backlog(test_app, client, make_user, login):
    tenant_id = _prepare_tenant(test_app)
    response, backlog = _capture_backlog(
        test_app,
        client,
        login,
        make_user("backlog-unsafe@example.test", tenant_id=tenant_id),
        {
            "username": "test-unsafe",
            "role": "sensor",
            "device_id": "esp01",
            "password": "unsafe;passwort",
        },
        "/selfservice/mqtt/erstellen",
    )
    assert backlog is None
    assert "Tasmota-Backlog-Syntax" in response.data.decode("utf-8")


def _render_credentials(test_app, backlog):
    with test_app.test_request_context("/selfservice/mqtt/erstellen"):
        return render_template(
            "mqtt/credentials.html",
            username="test-sensor",
            password="geheim",
            tenant={"tenant_id": "de-hh-gs-test"},
            topic="umweltbox/de-hh-gs-test/esp01",
            backlog=backlog,
        )


def test_credentials_template_offers_download_and_qr(test_app):
    html = _render_credentials(test_app, "Backlog0 Test")
    assert 'id="tasmota-backlog"' in html
    assert "Backlog0 Test" in html
    assert 'id="tasmota-download"' in html
    assert "tasmota_config.txt" in html
    assert 'id="tasmota-qr"' in html
    assert "/selfservice/static/js/qrcode.min.js" in html
    assert "/selfservice/static/js/tasmota-config.js" in html


def test_credentials_template_without_backlog_has_no_download(test_app):
    html = _render_credentials(test_app, None)
    assert 'id="tasmota-download"' not in html
    assert 'id="tasmota-qr"' not in html
    assert "qrcode.min.js" not in html


def test_change_password_provides_backlog(test_app, client, make_user, login):
    tenant_id = _prepare_tenant(test_app)
    with test_app.app_context():
        db.session.add(
            MqttAccount(
                tenant_id=tenant_id,
                username="test-change",
                role="sensor",
            )
        )
        db.session.commit()
        account_id = MqttAccount.query.one().id
        Device.query.one().mqtt_account_id = account_id
        db.session.commit()

    response, backlog = _capture_backlog(
        test_app,
        client,
        login,
        make_user("backlog-change@example.test", tenant_id=tenant_id),
        {"password": "neues-passwort"},
        f"/selfservice/mqtt/{account_id}/passwort",
    )
    assert response.status_code == 200
    assert "MqttPassword neues-passwort" in backlog
    assert "Topic umweltbox/de-hh-gs-test/esp01" in backlog
