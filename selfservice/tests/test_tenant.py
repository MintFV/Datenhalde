from app.extensions import db
from app.models import Device, MqttAccount, Tenant, User


def test_tenant_request_creates_pending_and_assigns_user(test_app, client, make_user, login):
    user_id = make_user("user1@example.test")
    login(user_id)

    response = client.post(
        "/selfservice/tenant/beantragen",
        data={
            "name": "Gymnasium Max Planck",
            "school_type": "gym",
            "bundesland": "by",
            "city": "München",
            "contact_email": "kontakt@example.com",
            "lat": "48.1351",
            "lon": "11.5820",
        },
        follow_redirects=True,
    )

    assert response.status_code == 200
    with test_app.app_context():
        tenant = Tenant.query.one()
        user = db.session.get(User, user_id)
        assert tenant.status == "pending"
        assert tenant.tenant_id == "de-by-gym-gymnasium-max-planck"
        assert user.tenant_id == tenant.id


def test_non_admin_cannot_approve(test_app, client, make_user, login):
    with test_app.app_context():
        tenant = Tenant(
            tenant_id="de-hh-gs-test",
            name="Testschule",
            status="pending",
        )
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id

    login(make_user("user2@example.test"))
    response = client.post(f"/selfservice/admin/tenants/{tenant_id}/freigeben")

    assert response.status_code == 403
    with test_app.app_context():
        assert db.session.get(Tenant, tenant_id).status == "pending"


def test_admin_can_approve_and_suspend(test_app, client, make_user, login):
    with test_app.app_context():
        tenant = Tenant(tenant_id="de-hh-gs-test", name="Testschule", status="pending")
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id

    login(make_user("admin@example.test", role="admin"))
    assert client.post(f"/selfservice/admin/tenants/{tenant_id}/freigeben").status_code == 302
    with test_app.app_context():
        assert db.session.get(Tenant, tenant_id).status == "active"

    assert client.post(f"/selfservice/admin/tenants/{tenant_id}/suspendieren").status_code == 302
    with test_app.app_context():
        assert db.session.get(Tenant, tenant_id).status == "suspended"


def test_device_crud_is_scoped_to_tenant(test_app, client, make_user, login):
    with test_app.app_context():
        tenant = Tenant(tenant_id="de-hh-gs-test", name="Testschule", status="active")
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id

    owner_id = make_user("owner@example.test", tenant_id=tenant_id)
    other_id = make_user("other@example.test")
    login(owner_id)

    response = client.post(
        f"/selfservice/tenant/{tenant_id}/geraete/neu",
        data={
            "device_id": "esp-klassenraum",
            "device_type": "tasmota",
            "description": "BME280",
            "mqtt_account_id": "",
        },
        follow_redirects=True,
    )
    assert response.status_code == 200

    with test_app.app_context():
        device = Device.query.one()
        assert device.device_id == "esp-klassenraum"
        device_id = device.id

    login(other_id)
    assert client.get(f"/selfservice/tenant/geraete/{device_id}/bearbeiten").status_code == 403


def test_sensor_account_uses_selected_device(test_app, client, make_user, login):
    with test_app.app_context():
        tenant = Tenant(tenant_id="de-hh-gs-test", name="Testschule", status="active")
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id
        db.session.add(Device(tenant_id=tenant_id, device_id="esp01", device_type="tasmota"))
        db.session.commit()

    login(make_user("sensor-owner@example.test", tenant_id=tenant_id))

    response = client.post(
        "/selfservice/mqtt/erstellen",
        data={
            "username": "test-sensor",
            "role": "sensor",
            "device_id": "esp01",
            "password": "sicheres-passwort",
        },
        follow_redirects=True,
    )

    assert response.status_code == 200
    with test_app.app_context():
        account = MqttAccount.query.one()
        assert account.role == "sensor"
        with open(test_app.config["MOSQUITTO_ACL_FILE"], encoding="utf-8") as handle:
            acl = handle.read()
        assert "topic write umweltbox/de-hh-gs-test/esp01/#" in acl
        assert "topic read umweltbox/de-hh-gs-test/cmnd/esp01/#" in acl
        assert "readwrite" not in acl
        assert b"umweltbox/de-hh-gs-test/esp01" in response.data


def test_sensor_account_without_device_is_rejected(test_app, client, make_user, login):
    with test_app.app_context():
        tenant = Tenant(tenant_id="de-hh-gs-test", name="Testschule", status="active")
        db.session.add(tenant)
        db.session.commit()
        tenant_id = tenant.id

    login(make_user("sensor-owner2@example.test", tenant_id=tenant_id))
    client.post(
        "/selfservice/mqtt/erstellen",
        data={
            "username": "test-sensor-2",
            "role": "sensor",
            "device_id": "",
            "password": "sicheres-passwort",
        },
    )

    with test_app.app_context():
        assert MqttAccount.query.count() == 0
