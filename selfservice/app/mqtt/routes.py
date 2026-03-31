import logging
import secrets
import string

from flask import flash, redirect, render_template, url_for
from flask_login import current_user, login_required

from ..extensions import db
from ..models import MqttAccount
from . import bp
from . import service as mqtt_service
from .forms import ChangeMqttPasswordForm, CreateMqttAccountForm, DeleteMqttAccountForm

logger = logging.getLogger(__name__)


def _generate_password(length=16):
    """Generiert ein sicheres zufälliges Passwort."""
    alphabet = string.ascii_letters + string.digits + "!@#$%&*"
    return "".join(secrets.choice(alphabet) for _ in range(length))


@bp.route("/")
@login_required
def overview():
    if not current_user.tenant:
        flash(
            "Du musst zuerst einen Tenant anlegen, bevor du MQTT-Accounts verwalten kannst.",
            "warning",
        )
        return redirect(url_for("dashboard.overview"))

    accounts = MqttAccount.query.filter_by(tenant_id=current_user.tenant.id).all()
    return render_template("mqtt/overview.html", accounts=accounts, tenant=current_user.tenant)


@bp.route("/erstellen", methods=["GET", "POST"])
@login_required
def create():
    if not current_user.tenant:
        flash("Du musst zuerst einen Tenant anlegen.", "warning")
        return redirect(url_for("dashboard.overview"))

    tenant = current_user.tenant
    form = CreateMqttAccountForm()

    if form.validate_on_submit():
        username = form.username.data.strip()
        role = form.role.data
        password = form.password.data

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
            )

            account = MqttAccount(
                tenant_id=tenant.id,
                username=username,
                role=role,
            )
            db.session.add(account)
            db.session.commit()

            flash(f'MQTT-Account "{username}" erfolgreich erstellt.', "success")
            return render_template(
                "mqtt/credentials.html", username=username, password=password, tenant=tenant
            )
        except Exception:
            logger.exception("Fehler beim Erstellen von MQTT-Account: %s", username)
            db.session.rollback()
            flash("Fehler beim Erstellen des MQTT-Accounts.", "danger")

    return render_template("mqtt/create.html", form=form, tenant=tenant)


@bp.route("/<int:account_id>/passwort", methods=["GET", "POST"])
@login_required
def change_password(account_id):
    account = MqttAccount.query.get_or_404(account_id)

    # Sicherstellen, dass der Account zum Tenant des Users gehört
    if not current_user.tenant or account.tenant_id != current_user.tenant.id:
        flash("Zugriff verweigert.", "danger")
        return redirect(url_for("mqtt.overview"))

    form = ChangeMqttPasswordForm()
    if form.validate_on_submit():
        try:
            mqtt_service.change_mqtt_password(account.username, form.password.data)
            flash(f'Passwort für "{account.username}" wurde geändert.', "success")
            return render_template(
                "mqtt/credentials.html",
                username=account.username,
                password=form.password.data,
                tenant=current_user.tenant,
            )
        except Exception:
            logger.exception("Fehler beim Passwort-Ändern: %s", account.username)
            flash("Fehler beim Ändern des Passworts.", "danger")

    return render_template("mqtt/change_password.html", form=form, account=account)


@bp.route("/<int:account_id>/loeschen", methods=["GET", "POST"])
@login_required
def delete(account_id):
    account = MqttAccount.query.get_or_404(account_id)

    if not current_user.tenant or account.tenant_id != current_user.tenant.id:
        flash("Zugriff verweigert.", "danger")
        return redirect(url_for("mqtt.overview"))

    form = DeleteMqttAccountForm()
    if form.validate_on_submit():
        try:
            mqtt_service.deprovision_mqtt_account(account.username)
            db.session.delete(account)
            db.session.commit()
            flash(f'MQTT-Account "{account.username}" wurde gelöscht.', "success")
        except Exception:
            logger.exception("Fehler beim Löschen: %s", account.username)
            db.session.rollback()
            flash("Fehler beim Löschen des MQTT-Accounts.", "danger")
        return redirect(url_for("mqtt.overview"))

    return render_template("mqtt/delete.html", form=form, account=account)
