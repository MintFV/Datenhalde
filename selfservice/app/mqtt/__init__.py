from flask import Blueprint

bp = Blueprint("mqtt", __name__, template_folder="../templates/mqtt")

from . import routes  # noqa: E402, F401
