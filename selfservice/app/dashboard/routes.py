from flask import render_template
from flask_login import current_user, login_required

from . import bp


def _mqtt_topic(tenant_id: str, username: str, role: str) -> str:
    """Topic-Wert passend zur erteilten ACL (siehe mqtt.service.add_acl_rules)."""
    if role == "admin":
        return tenant_id
    return f"{tenant_id}/{username}"


@bp.route("/dashboard")
@login_required
def overview():
    tenant = getattr(current_user, "tenant", None)
    account = tenant.mqtt_accounts[0] if tenant and tenant.mqtt_accounts else None

    if account:
        username = account.username
        client = f"{username}_%06X"
        topic = _mqtt_topic(tenant.tenant_id, username, account.role)
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
