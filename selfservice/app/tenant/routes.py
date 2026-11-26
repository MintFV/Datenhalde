from typing import Any, cast

from flask import abort, flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from ..auth.decorators import admin_required
from ..extensions import db
from ..models import Device, MqttAccount, Tenant
from . import bp
from .forms import DeviceForm, TenantRequestForm
from .service import generate_tenant_id


def _user() -> Any:
    return cast(Any, current_user)


def _own_tenant(tenant_id: int) -> Tenant:
    tenant = db.session.get(Tenant, tenant_id)
    if tenant is None:
        abort(404)
    user = _user()
    if tenant.id != getattr(user, "tenant_id", None) and getattr(user, "role", None) != "admin":
        abort(403)
    return tenant


def _device(device_id: int) -> Device:
    device = db.session.get(Device, device_id)
    if device is None:
        abort(404)
    _own_tenant(device.tenant_id)
    return device


@bp.route("/tenant/beantragen", methods=["GET", "POST"])
@login_required
def request_tenant():
    if _user().tenant:
        flash("Du hast bereits einen Tenant.", "info")
        return redirect(url_for("tenant.overview"))

    form = TenantRequestForm()
    if form.validate_on_submit():
        existing = [value for (value,) in db.session.query(Tenant.tenant_id).all()]
        tenant_id = generate_tenant_id(
            form.name.data.strip(),
            form.bundesland.data,
            form.school_type.data,
            existing,
        )
        tenant = Tenant(
            tenant_id=tenant_id,
            name=form.name.data.strip(),
            school_type=form.school_type.data,
            bundesland=form.bundesland.data,
            city=(form.city.data or "").strip() or None,
            contact_email=(form.contact_email.data or "").strip() or None,
            lat=form.lat.data,
            lon=form.lon.data,
            status="pending",
        )
        db.session.add(tenant)
        db.session.flush()
        _user().tenant_id = tenant.id
        db.session.commit()
        flash(
            f'Tenant "{tenant_id}" beantragt. Ein Administrator muss ihn freigeben.',
            "success",
        )
        return redirect(url_for("tenant.overview"))

    return render_template("tenant/request.html", form=form)


@bp.route("/tenant/uebersicht")
@login_required
def overview():
    tenant = _user().tenant
    return render_template("tenant/overview.html", tenant=tenant)


@bp.route("/tenant/<int:tenant_id>/geraete/neu", methods=["GET", "POST"])
@login_required
def device_create(tenant_id: int):
    tenant = _own_tenant(tenant_id)
    form = DeviceForm()
    form.mqtt_account_id.choices = [("", "— keiner —")] + [
        (str(account.id), account.username)
        for account in MqttAccount.query.filter_by(tenant_id=tenant.id).all()
    ]

    if form.validate_on_submit():
        existing_devices = Device.query.filter_by(tenant_id=tenant.id).all()
        if any(device.device_id == form.device_id.data for device in existing_devices):
            flash(
                f'Gerät "{form.device_id.data}" existiert in diesem Tenant bereits.',
                "danger",
            )
        else:
            selected = form.mqtt_account_id.data
            account = db.session.get(MqttAccount, int(selected)) if selected else None
            if account is not None and account.tenant_id != tenant.id:
                abort(403)
            device = Device(
                tenant_id=tenant.id,
                device_id=form.device_id.data.strip(),
                device_type=form.device_type.data,
                description=(form.description.data or "").strip() or None,
                mqtt_account_id=account.id if account else None,
            )
            db.session.add(device)
            db.session.commit()
            flash(f'Gerät "{device.device_id}" angelegt.', "success")
            return redirect(url_for("tenant.overview"))

    return render_template("tenant/device_form.html", form=form, tenant=tenant)


@bp.route("/tenant/geraete/<int:device_id>/bearbeiten", methods=["GET", "POST"])
@login_required
def device_edit(device_id: int):
    device = _device(device_id)
    tenant = _own_tenant(device.tenant_id)
    form = DeviceForm()
    if request.method == "GET":
        form.device_id.data = device.device_id
        form.device_type.data = device.device_type
        form.description.data = device.description
    form.mqtt_account_id.choices = [("", "— keiner —")] + [
        (str(account.id), account.username)
        for account in MqttAccount.query.filter_by(tenant_id=tenant.id).all()
    ]
    form.mqtt_account_id.data = str(device.mqtt_account_id) if device.mqtt_account_id else ""

    if form.validate_on_submit():
        selected = form.mqtt_account_id.data
        account = db.session.get(MqttAccount, int(selected)) if selected else None
        if account is not None and account.tenant_id != tenant.id:
            abort(403)
        if account is not None:
            linked = Device.query.filter_by(mqtt_account_id=account.id).first()
            if linked is not None and linked.id != device.id:
                flash(
                    "Dieser MQTT-Account ist bereits mit einem anderen Gerät verknüpft.",
                    "warning",
                )
                return render_template(
                    "tenant/device_form.html", form=form, tenant=tenant, device=device
                )
        device.device_id = form.device_id.data.strip()
        device.device_type = form.device_type.data
        device.description = (form.description.data or "").strip() or None
        device.mqtt_account_id = account.id if account else None
        db.session.commit()
        flash(f'Gerät "{device.device_id}" aktualisiert.', "success")
        return redirect(url_for("tenant.overview"))

    return render_template("tenant/device_form.html", form=form, tenant=tenant, device=device)


@bp.route("/tenant/geraete/<int:device_id>/loeschen", methods=["GET", "POST"])
@login_required
def device_delete(device_id: int):
    device = _device(device_id)
    if device.mqtt_account_id is not None:
        flash(
            "Gerät ist noch mit einem MQTT-Account verknüpft. "
            "Bitte zuerst die Verknüpfung entfernen.",
            "warning",
        )
        return redirect(url_for("tenant.overview"))

    if request.method == "POST":
        db.session.delete(device)
        db.session.commit()
        flash(f'Gerät "{device.device_id}" gelöscht.', "success")
        return redirect(url_for("tenant.overview"))

    return render_template("tenant/device_delete.html", device=device)


@bp.route("/admin/tenants")
@login_required
@admin_required
def admin_tenants():
    tenants = Tenant.query.order_by(Tenant.created_at.desc()).all()
    return render_template("admin/tenants.html", tenants=tenants)


@bp.route("/admin/tenants/<int:tenant_id>/freigeben", methods=["POST"])
@login_required
@admin_required
def admin_approve(tenant_id: int):
    tenant = db.session.get(Tenant, tenant_id)
    if tenant is None:
        abort(404)
    tenant.status = "active"
    db.session.commit()
    flash(f'Tenant "{tenant.tenant_id}" freigegeben.', "success")
    return redirect(url_for("tenant.admin_tenants"))


@bp.route("/admin/tenants/<int:tenant_id>/suspendieren", methods=["POST"])
@login_required
@admin_required
def admin_suspend(tenant_id: int):
    tenant = db.session.get(Tenant, tenant_id)
    if tenant is None:
        abort(404)
    tenant.status = "suspended"
    db.session.commit()
    flash(f'Tenant "{tenant.tenant_id}" suspendiert.', "warning")
    return redirect(url_for("tenant.admin_tenants"))
