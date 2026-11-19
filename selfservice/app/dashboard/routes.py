from flask import render_template
from flask_login import current_user, login_required

from ..mqtt.service import topic_for
from . import bp


@bp.route("/dashboard")
@login_required
def overview():
    tenant = getattr(current_user, "tenant", None)
    account = tenant.mqtt_accounts[0] if tenant and tenant.mqtt_accounts else None

    if account:
        username = account.username
        client = f"{username}_%06X"
        topic = topic_for(
            tenant.tenant_id,
            account.role,
            username,
            account.device.device_id if account.device else None,
        )
    else:
        username = ""
        client = "DVES_%06X"
        topic = tenant.tenant_id if tenant else ""

    return render_template(
        "dashboard/overview.html",
        user=current_user,
        mqtt_username=username,
        mqtt_client=client,
        mqtt_topic=topic,
    )
