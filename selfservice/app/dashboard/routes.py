from flask import render_template
from flask_login import current_user, login_required

from . import bp


@bp.route("/dashboard")
@login_required
def overview():
    return render_template("dashboard/overview.html", user=current_user)
