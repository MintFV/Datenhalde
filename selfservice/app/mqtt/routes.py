from __future__ import annotations

import importlib
import logging
import secrets
import string
from collections.abc import Callable
from typing import Any, ParamSpec, Protocol, TypeVar, cast

from flask import current_app, flash, redirect, render_template, url_for

from ..extensions import db
from ..models import Device, MqttAccount
from . import bp
from . import service as mqtt_service
from .forms import (
    ChangeMqttPasswordForm,
    CreateMqttAccountForm,
    DeleteMqttAccountForm,
)
from .service import topic_for
from .tasmota import (
    INVALID_PASSWORD_MESSAGE,
    build_tasmota_backlog,
    is_tasmota_password_safe,
)

logger = logging.getLogger(__name__)

P = ParamSpec("P")
R = TypeVar("R")


class TenantProtocol(Protocol):
    id: int
    tenant_id: str
    status: str


class CurrentUserProtocol(Protocol):
    tenant: TenantProtocol | None


flask_login_module: Any = importlib.import_module("flask_login")
_flask_login: Any = flask_login_module
current_user: CurrentUserProtocol = cast(CurrentUserProtocol, _flask_login.current_user)


def login_required(  # noqa: UP047
    view_func: Callable[P, R],
) -> Callable[P, R]:
    return cast(Callable[P, R], _flask_login.login_required(view_func))


def _form_str(value: object | None) -> str:
    return value if isinstance(value, str) else ""


def _active_tenant() -> TenantProtocol | None:
    tenant = current_user.tenant
    if not tenant:
        flash(
            "Du musst zuerst einen Tenant anlegen, bevor du MQTT-Accounts verwalten kannst.",
            "warning",
        )
        return None
    if tenant.status != "active":
        flash(
            "Dein Tenant ist noch nicht freigegeben oder wurde suspendiert.",
            "warning",
        )
        return None
    return tenant


def _generate_password(length: int = 16) -> str:
    """Generiert ein sicheres zufälliges Passwort."""
    alphabet = string.ascii_letters + string.digits + "!@#$%&*"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def _tasmota_backlog(
    tenant: TenantProtocol,
    username: str,
    role: str,
    password: str,
    device: Device | None,
) -> str | None:
    if device is None or device.device_type != "tasmota":
        return None
    if not is_tasmota_password_safe(password):
        flash(INVALID_PASSWORD_MESSAGE, "warning")
        return None
    return build_tasmota_backlog(
        domain=str(current_app.config["DOMAIN"]),
        topic=topic_for(tenant.tenant_id, role, username, device.device_id),
        username=username,
        password=password,
        client=device.device_id,
    )


@bp.route("/")
@login_required
def overview():
    tenant = _active_tenant()
    if not tenant:
        return redirect(url_for("dashboard.overview"))

    accounts = MqttAccount.query.filter_by(tenant_id=tenant.id).all()
    topics = {
        account.id: topic_for(
            tenant.tenant_id,
            account.role,
            account.username,
            account.device.device_id if account.device else None,
        )
        for account in accounts
    }
    return render_template(
        "mqtt/overview.html",
        accounts=accounts,
        topics=topics,
        tenant=tenant,
    )


@bp.route("/erstellen", methods=["GET", "POST"])
@login_required
def create():
    tenant = _active_tenant()
    if not tenant:
        return redirect(url_for("dashboard.overview"))

    form = CreateMqttAccountForm()
    form.device_id.choices = [("", "— keines —")] + [
        (device.device_id, f"{device.device_id} ({device.device_type})")
        for device in tenant.devices
    ]

    if form.validate_on_submit():
        username = _form_str(form.username.data).strip()
        role = _form_str(form.role.data)
        password = _form_str(form.password.data)
        device_id = _form_str(form.device_id.data) or None

        if role == "sensor" and not device_id:
            flash("Für einen Sensor muss ein Gerät ausgewählt werden.", "danger")
            return render_template("mqtt/create.html", form=form, tenant=tenant)

        device = None
        if device_id:
            device = Device.query.filter_by(tenant_id=tenant.id, device_id=device_id).first()
            if device is None:
                flash(
                    f'Gerät "{device_id}" gehört nicht zu diesem Tenant.',
                    "danger",
                )
                return render_template("mqtt/create.html", form=form, tenant=tenant)
            if device.mqtt_account_id is not None:
                flash(
                    f'Gerät "{device_id}" ist bereits mit einem MQTT-Account verknüpft.',
                    "danger",
                )
                return render_template("mqtt/create.html", form=form, tenant=tenant)

        # Prüfen ob Username bereits existiert
        if MqttAccount.query.filter_by(username=username).first():
            flash(f'MQTT-Account "{username}" existiert bereits.', "danger")
            return render_template("mqtt/create.html", form=form, tenant=tenant)

        if mqtt_service.mqtt_user_exists(username):
            flash(
                f'MQTT-Benutzername "{username}" ist bereits '
                "in der Mosquitto-Konfiguration vergeben.",
                "danger",
            )
            return render_template("mqtt/create.html", form=form, tenant=tenant)

        try:
            mqtt_service.provision_mqtt_account(
                username=username,
                password=password,
                tenant_id=tenant.tenant_id,
                role=role,
                device_id=device_id,
            )

            account_model = cast(Any, MqttAccount)
            account = cast(
                MqttAccount,
                account_model(
                    tenant_id=tenant.id,
                    username=username,
                    role=role,
                ),
            )
            db.session.add(account)
            if device is not None:
                device.mqtt_account = account
            db.session.commit()

            flash(
                f'MQTT-Account "{username}" erfolgreich erstellt.',
                "success",
            )
            return render_template(
                "mqtt/credentials.html",
                username=username,
                password=password,
                tenant=tenant,
                topic=topic_for(tenant.tenant_id, role, username, device_id),
                backlog=_tasmota_backlog(tenant, username, role, password, device),
            )
        except (OSError, ValueError, RuntimeError):
            logger.exception(
                "Fehler beim Erstellen von MQTT-Account: %s",
                username,
            )
            db.session.rollback()
            flash("Fehler beim Erstellen des MQTT-Accounts.", "danger")

    return render_template("mqtt/create.html", form=form, tenant=tenant)


@bp.route("/<int:account_id>/passwort", methods=["GET", "POST"])
@login_required
def change_password(account_id: int):
    tenant = _active_tenant()
    if not tenant:
        return redirect(url_for("dashboard.overview"))
    account = MqttAccount.query.get_or_404(account_id)

    if account.tenant_id != tenant.id:
        flash("Zugriff verweigert.", "danger")
        return redirect(url_for("mqtt.overview"))

    form = ChangeMqttPasswordForm()
    if form.validate_on_submit():
        try:
            new_password = _form_str(form.password.data)
            mqtt_service.change_mqtt_password(account.username, new_password)
            flash(
                f'Passwort für "{account.username}" wurde geändert.',
                "success",
            )
            return render_template(
                "mqtt/credentials.html",
                username=account.username,
                password=new_password,
                tenant=tenant,
                topic=topic_for(
                    tenant.tenant_id,
                    account.role,
                    account.username,
                    account.device.device_id if account.device else None,
                ),
                backlog=_tasmota_backlog(
                    tenant,
                    account.username,
                    account.role,
                    new_password,
                    account.device,
                ),
            )
        except (OSError, ValueError, RuntimeError):
            logger.exception("Fehler beim Passwort-Ändern: %s", account.username)
            flash("Fehler beim Ändern des Passworts.", "danger")

    return render_template(
        "mqtt/change_password.html",
        form=form,
        account=account,
    )


@bp.route("/<int:account_id>/loeschen", methods=["GET", "POST"])
@login_required
def delete(account_id: int):
    tenant = _active_tenant()
    if not tenant:
        return redirect(url_for("dashboard.overview"))
    account = MqttAccount.query.get_or_404(account_id)

    if account.tenant_id != tenant.id:
        flash("Zugriff verweigert.", "danger")
        return redirect(url_for("mqtt.overview"))

    form = DeleteMqttAccountForm()
    if form.validate_on_submit():
        try:
            mqtt_service.deprovision_mqtt_account(account.username)
            db.session.delete(account)
            db.session.commit()
            flash(
                f'MQTT-Account "{account.username}" wurde gelöscht.',
                "success",
            )
        except (OSError, ValueError, RuntimeError):
            logger.exception("Fehler beim Löschen: %s", account.username)
            db.session.rollback()
            flash("Fehler beim Löschen des MQTT-Accounts.", "danger")
        return redirect(url_for("mqtt.overview"))

    return render_template("mqtt/delete.html", form=form, account=account)
