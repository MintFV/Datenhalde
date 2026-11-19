import pytest

from app.mqtt.service import add_acl_rules, provision_mqtt_account, topic_for


def _read_acl(test_app) -> str:
    with open(test_app.config["MOSQUITTO_ACL_FILE"], encoding="utf-8") as handle:
        return handle.read()


def test_admin_rules(test_app):
    with test_app.app_context():
        add_acl_rules("tenant-admin", "de-hh-gs-test", "admin")
    acl = _read_acl(test_app)
    assert "topic readwrite umweltbox/de-hh-gs-test/#" in acl
    assert "topic read $SYS/broker/version" in acl


def test_sensor_rules_are_device_scoped(test_app):
    with test_app.app_context():
        add_acl_rules("tenant-sensor", "de-hh-gs-test", "sensor", "esp01")
    acl = _read_acl(test_app)
    assert "topic write umweltbox/de-hh-gs-test/esp01/#" in acl
    assert "topic read umweltbox/de-hh-gs-test/cmnd/esp01/#" in acl
    assert "readwrite" not in acl


def test_nodered_rules_are_read_only(test_app):
    with test_app.app_context():
        add_acl_rules("tenant-nodered", "de-hh-gs-test", "nodered")
    acl = _read_acl(test_app)
    assert "topic read umweltbox/de-hh-gs-test/#" in acl
    assert "readwrite" not in acl


def test_sensor_without_device_fails_closed(test_app):
    with test_app.app_context(), pytest.raises(ValueError):
        add_acl_rules("tenant-sensor", "de-hh-gs-test", "sensor")


def test_unknown_role_fails_closed(test_app):
    with test_app.app_context(), pytest.raises(ValueError):
        add_acl_rules("tenant-unknown", "de-hh-gs-test", "unknown")


def test_provision_replaces_stale_acl(test_app):
    with test_app.app_context():
        add_acl_rules("tenant-user", "de-hh-gs-test", "admin")
        assert "readwrite" in _read_acl(test_app)
        provision_mqtt_account(
            username="tenant-user",
            password="sicheres-passwort",
            tenant_id="de-hh-gs-test",
            role="sensor",
            device_id="esp01",
        )
    acl = _read_acl(test_app)
    assert "readwrite" not in acl
    assert "topic write umweltbox/de-hh-gs-test/esp01/#" in acl


@pytest.mark.parametrize(
    ("role", "device_id", "expected"),
    [
        ("admin", None, "umweltbox/de-hh-gs-test"),
        ("nodered", None, "umweltbox/de-hh-gs-test"),
        ("sensor", "esp01", "umweltbox/de-hh-gs-test/esp01"),
        ("sensor", None, "umweltbox/de-hh-gs-test/tenant-sensor"),
    ],
)
def test_topic_for(role, device_id, expected):
    assert topic_for("de-hh-gs-test", role, "tenant-sensor", device_id) == expected
